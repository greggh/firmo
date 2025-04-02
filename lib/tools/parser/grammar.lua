--[[
This module implements a parser for Lua 5.3/5.4 with LPeg,
and generates an Abstract Syntax Tree.

Based on lua-parser by Andre Murbach Maidl (https://github.com/andremm/lua-parser)
]]

---@class parser.grammar
---@field _VERSION string Module version
---@field parser fun(subject: string, filename?: string): table|nil, table? Parse Lua code into an abstract syntax tree
---@field error_labels table<string, string> Table mapping error label names to error messages
---@field compile_grammar fun(options?: {annotate_positions?: boolean, label_errors?: boolean, extract_comments?: boolean}): table Compile the Lua grammar with the specified options
---@field extract_comments fun(subject: string): table<number, {line: number, text: string, type: string}> Extract comments from Lua source code
---@field parse_expression fun(subject: string): table|nil, table? Parse a Lua expression (not a full chunk)
---@field tokenize fun(subject: string): table<number, {type: string, value: string, line: number, col: number}> Split Lua code into tokens

local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("grammar")
logging.configure_from_config("grammar")

local M = {
  -- Module version
  _VERSION = "1.0.0",
}

-- UTF-8 char polyfill for pre-5.3 Lua versions
-- Based on PR #19 from lua-parser: https://github.com/andremm/lua-parser/pull/19
-- This allows correctly handling UTF-8 characters in all Lua versions
-- without depending on the utf8 library (which is only available in Lua 5.3+)
---@diagnostic disable-next-line: undefined-global
local utf8_char = (utf8 or {
  char = function(...)
    local results = { ... }
    local n = select("#", ...)

    for i = 1, n do
      local a = results[i]

      if type(a) ~= "number" then
        a = tonumber(a) or error("bad argument #" .. i .. " to 'char' (number expected, got " .. type(a) .. ")", 2)
      end

      if not (0 <= a) or a > 1114111 or a % 1 ~= 0 then
        error("bad argument #" .. i .. " to 'char' (expected an integer in the range [0, 1114111], got " .. a .. ")", 2)
      end

      if a >= 128 then
        local _1 = a % 64
        local b = (a - _1) / 64

        if a >= 2048 then
          local _64 = b % 64
          local c = (b - _64) / 64

          if a >= 65536 then
            local _4096 = c % 64
            local d = (c - _4096) / 64
            results[i] = string.char(d + 240, _4096 + 128, _64 + 128, _1 + 128)
          else
            results[i] = string.char(c + 224, _64 + 128, _1 + 128)
          end
        else
          results[i] = string.char(b + 192, _1 + 128)
        end
      else
        results[i] = string.char(a)
      end
    end
    return table.concat(results, nil, 1, n)
  end,
  ---@diagnostic disable-next-line: undefined-field
}).char

-- Load LPegLabel
local lpeg = require("lib.tools.vendor.lpeglabel")

---@diagnostic disable-next-line: redundant-parameter
lpeg.locale(lpeg)

local P, S, V = lpeg.P, lpeg.S, lpeg.V
local C, Carg, Cb, Cc = lpeg.C, lpeg.Carg, lpeg.Cb, lpeg.Cc
local Cf, Cg, Cmt, Cp, Cs, Ct = lpeg.Cf, lpeg.Cg, lpeg.Cmt, lpeg.Cp, lpeg.Cs, lpeg.Ct
local Lc, T = lpeg.Lc, lpeg.T

local alpha, digit, alnum = lpeg.alpha, lpeg.digit, lpeg.alnum
local xdigit = lpeg.xdigit
local space = lpeg.space

-- Error message auxiliary functions
local labels = {
  { "ErrExtra", "unexpected character(s), expected EOF" },
  { "ErrInvalidStat", "unexpected token, invalid start of statement" },

  { "ErrEndIf", "expected 'end' to close the if statement" },
  { "ErrExprIf", "expected a condition after 'if'" },
  { "ErrThenIf", "expected 'then' after the condition" },
  { "ErrExprEIf", "expected a condition after 'elseif'" },
  { "ErrThenEIf", "expected 'then' after the condition" },

  { "ErrEndDo", "expected 'end' to close the do block" },
  { "ErrExprWhile", "expected a condition after 'while'" },
  { "ErrDoWhile", "expected 'do' after the condition" },
  { "ErrEndWhile", "expected 'end' to close the while loop" },
  { "ErrUntilRep", "expected 'until' at the end of the repeat loop" },
  { "ErrExprRep", "expected a conditions after 'until'" },

  { "ErrForRange", "expected a numeric or generic range after 'for'" },
  { "ErrEndFor", "expected 'end' to close the for loop" },
  { "ErrExprFor1", "expected a starting expression for the numeric range" },
  { "ErrCommaFor", "expected ',' to split the start and end of the range" },
  { "ErrExprFor2", "expected an ending expression for the numeric range" },
  { "ErrExprFor3", "expected a step expression for the numeric range after ','" },
  { "ErrInFor", "expected '=' or 'in' after the variable(s)" },
  { "ErrEListFor", "expected one or more expressions after 'in'" },
  { "ErrDoFor", "expected 'do' after the range of the for loop" },

  { "ErrDefLocal", "expected a function definition or assignment after local" },
  { "ErrNameLFunc", "expected a function name after 'function'" },
  { "ErrEListLAssign", "expected one or more expressions after '='" },
  { "ErrEListAssign", "expected one or more expressions after '='" },

  { "ErrFuncName", "expected a function name after 'function'" },
  { "ErrNameFunc1", "expected a function name after '.'" },
  { "ErrNameFunc2", "expected a method name after ':'" },
  { "ErrOParenPList", "expected '(' for the parameter list" },
  { "ErrCParenPList", "expected ')' to close the parameter list" },
  { "ErrEndFunc", "expected 'end' to close the function body" },
  { "ErrParList", "expected a variable name or '...' after ','" },

  { "ErrLabel", "expected a label name after '::'" },
  { "ErrCloseLabel", "expected '::' after the label" },
  { "ErrGoto", "expected a label after 'goto'" },
  { "ErrRetList", "expected an expression after ',' in the return statement" },

  { "ErrVarList", "expected a variable name after ','" },
  { "ErrExprList", "expected an expression after ','" },

  { "ErrOrExpr", "expected an expression after 'or'" },
  { "ErrAndExpr", "expected an expression after 'and'" },
  { "ErrRelExpr", "expected an expression after the relational operator" },
  { "ErrBOrExpr", "expected an expression after '|'" },
  { "ErrBXorExpr", "expected an expression after '~'" },
  { "ErrBAndExpr", "expected an expression after '&'" },
  { "ErrShiftExpr", "expected an expression after the bit shift" },
  { "ErrConcatExpr", "expected an expression after '..'" },
  { "ErrAddExpr", "expected an expression after the additive operator" },
  { "ErrMulExpr", "expected an expression after the multiplicative operator" },
  { "ErrUnaryExpr", "expected an expression after the unary operator" },
  { "ErrPowExpr", "expected an expression after '^'" },

  { "ErrExprParen", "expected an expression after '('" },
  { "ErrCParenExpr", "expected ')' to close the expression" },
  { "ErrNameIndex", "expected a field name after '.'" },
  { "ErrExprIndex", "expected an expression after '['" },
  { "ErrCBracketIndex", "expected ']' to close the indexing expression" },
  { "ErrNameMeth", "expected a method name after ':'" },
  { "ErrMethArgs", "expected some arguments for the method call (or '()')" },

  { "ErrArgList", "expected an expression after ',' in the argument list" },
  { "ErrCParenArgs", "expected ')' to close the argument list" },

  { "ErrCBraceTable", "expected '}' to close the table constructor" },
  { "ErrEqField", "expected '=' after the table key" },
  { "ErrExprField", "expected an expression after '='" },
  { "ErrExprFKey", "expected an expression after '[' for the table key" },
  { "ErrCBracketFKey", "expected ']' to close the table key" },

  { "ErrDigitHex", "expected one or more hexadecimal digits after '0x'" },
  { "ErrDigitDeci", "expected one or more digits after the decimal point" },
  { "ErrDigitExpo", "expected one or more digits for the exponent" },

  { "ErrQuote", "unclosed string" },
  { "ErrHexEsc", "expected exactly two hexadecimal digits after '\\x'" },
  { "ErrOBraceUEsc", "expected '{' after '\\u'" },
  { "ErrDigitUEsc", "expected one or more hexadecimal digits for the UTF-8 code point" },
  { "ErrCBraceUEsc", "expected '}' after the code point" },
  { "ErrEscSeq", "invalid escape sequence" },
  { "ErrCloseLStr", "unclosed long string" },
}

local function throw(label)
  label = "Err" .. label

  logger.debug("Throwing syntax error", {
    label = label,
  })

  for i, labelinfo in ipairs(labels) do
    if labelinfo[1] == label then
      return T(i)
    end
  end

  logger.error("Error label not found", {
    requested_label = label,
  })

  error("Label not found: " .. label)
end

local function expect(patt, label)
  return patt + throw(label)
end

-- Regular combinators and auxiliary functions
local function token(patt)
  return patt * V("Skip")
end

local function sym(str)
  return token(P(str))
end

local function kw(str)
  return token(P(str) * -V("IdRest"))
end

local function dec(n)
  return n - 1
end

local function tagC(tag, patt)
  ---@diagnostic disable-next-line: redundant-parameter
  return Ct(Cg(Cp(), "pos") * Cg(Cc(tag), "tag") * patt * Cg(Cp() / dec, "end_pos"))
end

local function unaryOp(op, e)
  return { tag = "Op", pos = e.pos, end_pos = e.end_pos, [1] = op, [2] = e }
end

local function binaryOp(e1, op, e2)
  if not op then
    return e1
  else
    return { tag = "Op", pos = e1.pos, end_pos = e2.end_pos, [1] = op, [2] = e1, [3] = e2 }
  end
end

local function sepBy(patt, sep, label)
  if label then
    return patt * Cg(sep * expect(patt, label)) ^ 0
  else
    return patt * Cg(sep * patt) ^ 0
  end
end

-- Helper function to prevent subcapture nesting too deep errors
-- Based on PR #21 from lua-parser: https://github.com/andremm/lua-parser/pull/21
-- This addresses an issue with parsing deeply nested tables (>16 levels)
local function cut(s, idx, match)
  return idx, match
end

local function chainOp(patt, sep, label)
  ---@diagnostic disable-next-line: redundant-parameter
  return Cmt(Cf(sepBy(patt, sep, label), binaryOp), cut)
end

local function commaSep(patt, label)
  return sepBy(patt, sym(","), label)
end

local function tagDo(block)
  block.tag = "Do"
  return block
end

local function fixFuncStat(func)
  if func[1].is_method then
    table.insert(func[2][1], 1, { tag = "Id", [1] = "self" })
  end
  func[1] = { func[1] }
  func[2] = { func[2] }
  return func
end

local function addDots(params, dots)
  if dots then
    table.insert(params, dots)
  end
  return params
end

local function insertIndex(t, index)
  return { tag = "Index", pos = t.pos, end_pos = index.end_pos, [1] = t, [2] = index }
end

local function markMethod(t, method)
  if method then
    return { tag = "Index", pos = t.pos, end_pos = method.end_pos, is_method = true, [1] = t, [2] = method }
  end
  return t
end

local function makeIndexOrCall(t1, t2)
  if t2.tag == "Call" or t2.tag == "Invoke" then
    local t = { tag = t2.tag, pos = t1.pos, end_pos = t2.end_pos, [1] = t1 }
    for k, v in ipairs(t2) do
      table.insert(t, v)
    end
    return t
  end
  return { tag = "Index", pos = t1.pos, end_pos = t2.end_pos, [1] = t1, [2] = t2[1] }
end

-- Grammar
local G = {
  V("Lua"),
  Lua = V("Shebang") ^ -1 * V("Skip") * V("Block") * expect(P(-1), "Extra"),
  Shebang = P("#!") * (P(1) - P("\n")) ^ 0,

  Block = tagC("Block", V("Stat") ^ 0 * V("RetStat") ^ -1),
  Stat = V("IfStat")
    + V("DoStat")
    + V("WhileStat")
    + V("RepeatStat")
    + V("ForStat")
    + V("LocalStat")
    + V("FuncStat")
    + V("BreakStat")
    + V("LabelStat")
    + V("GoToStat")
    + V("FuncCall")
    + V("Assignment")
    + sym(";")
    + -V("BlockEnd") * throw("InvalidStat"),
  BlockEnd = P("return") + "end" + "elseif" + "else" + "until" + -1,

  IfStat = tagC("If", V("IfPart") * V("ElseIfPart") ^ 0 * V("ElsePart") ^ -1 * expect(kw("end"), "EndIf")),
  IfPart = kw("if") * expect(V("Expr"), "ExprIf") * expect(kw("then"), "ThenIf") * V("Block"),
  ElseIfPart = kw("elseif") * expect(V("Expr"), "ExprEIf") * expect(kw("then"), "ThenEIf") * V("Block"),
  ElsePart = kw("else") * V("Block"),

  DoStat = kw("do") * V("Block") * expect(kw("end"), "EndDo") / tagDo,
  WhileStat = tagC("While", kw("while") * expect(V("Expr"), "ExprWhile") * V("WhileBody")),
  WhileBody = expect(kw("do"), "DoWhile") * V("Block") * expect(kw("end"), "EndWhile"),
  RepeatStat = tagC(
    "Repeat",
    kw("repeat") * V("Block") * expect(kw("until"), "UntilRep") * expect(V("Expr"), "ExprRep")
  ),

  ForStat = kw("for") * expect(V("ForNum") + V("ForIn"), "ForRange") * expect(kw("end"), "EndFor"),
  ForNum = tagC("Fornum", V("Id") * sym("=") * V("NumRange") * V("ForBody")),
  NumRange = expect(V("Expr"), "ExprFor1")
    * expect(sym(","), "CommaFor")
    * expect(V("Expr"), "ExprFor2")
    * (sym(",") * expect(V("Expr"), "ExprFor3")) ^ -1,
  ForIn = tagC("Forin", V("NameList") * expect(kw("in"), "InFor") * expect(V("ExprList"), "EListFor") * V("ForBody")),
  ForBody = expect(kw("do"), "DoFor") * V("Block"),

  LocalStat = kw("local") * expect(V("LocalFunc") + V("LocalAssign"), "DefLocal"),
  LocalFunc = tagC("Localrec", kw("function") * expect(V("Id"), "NameLFunc") * V("FuncBody")) / fixFuncStat,
  LocalAssign = tagC("Local", V("NameList") * (sym("=") * expect(V("ExprList"), "EListLAssign") + Ct(Cc()))),
  Assignment = tagC("Set", V("VarList") * sym("=") * expect(V("ExprList"), "EListAssign")),

  FuncStat = tagC("Set", kw("function") * expect(V("FuncName"), "FuncName") * V("FuncBody")) / fixFuncStat,
  ---@diagnostic disable-next-line: redundant-parameter
  FuncName = Cf(V("Id") * (sym(".") * expect(V("StrId"), "NameFunc1")) ^ 0, insertIndex)
    * (sym(":") * expect(V("StrId"), "NameFunc2")) ^ -1
    / markMethod,
  FuncBody = tagC("Function", V("FuncParams") * V("Block") * expect(kw("end"), "EndFunc")),
  FuncParams = expect(sym("("), "OParenPList") * V("ParList") * expect(sym(")"), "CParenPList"),
  ParList = V("NameList") * (sym(",") * expect(tagC("Dots", sym("...")), "ParList")) ^ -1 / addDots + Ct(
    tagC("Dots", sym("..."))
  ) + Ct(Cc()), -- Cc({}) generates a bug since the {} would be shared across parses

  LabelStat = tagC("Label", sym("::") * expect(V("Name"), "Label") * expect(sym("::"), "CloseLabel")),
  GoToStat = tagC("Goto", kw("goto") * expect(V("Name"), "Goto")),
  BreakStat = tagC("Break", kw("break")),
  RetStat = tagC("Return", kw("return") * commaSep(V("Expr"), "RetList") ^ -1 * sym(";") ^ -1),

  NameList = tagC("NameList", commaSep(V("Id"))),
  VarList = tagC("VarList", commaSep(V("VarExpr"), "VarList")),
  ExprList = tagC("ExpList", commaSep(V("Expr"), "ExprList")),

  Expr = V("OrExpr"),
  OrExpr = chainOp(V("AndExpr"), V("OrOp"), "OrExpr"),
  AndExpr = chainOp(V("RelExpr"), V("AndOp"), "AndExpr"),
  RelExpr = chainOp(V("BOrExpr"), V("RelOp"), "RelExpr"),
  BOrExpr = chainOp(V("BXorExpr"), V("BOrOp"), "BOrExpr"),
  BXorExpr = chainOp(V("BAndExpr"), V("BXorOp"), "BXorExpr"),
  BAndExpr = chainOp(V("ShiftExpr"), V("BAndOp"), "BAndExpr"),
  ShiftExpr = chainOp(V("ConcatExpr"), V("ShiftOp"), "ShiftExpr"),
  ConcatExpr = V("AddExpr") * (V("ConcatOp") * expect(V("ConcatExpr"), "ConcatExpr")) ^ -1 / binaryOp,
  AddExpr = chainOp(V("MulExpr"), V("AddOp"), "AddExpr"),
  MulExpr = chainOp(V("UnaryExpr"), V("MulOp"), "MulExpr"),
  UnaryExpr = V("UnaryOp") * expect(V("UnaryExpr"), "UnaryExpr") / unaryOp + V("PowExpr"),
  PowExpr = V("SimpleExpr") * (V("PowOp") * expect(V("UnaryExpr"), "PowExpr")) ^ -1 / binaryOp,

  SimpleExpr = tagC("Number", V("Number")) + tagC("String", V("String")) + tagC("Nil", kw("nil")) + tagC(
    "Boolean",
    kw("false") * Cc(false)
  ) + tagC("Boolean", kw("true") * Cc(true)) + tagC("Dots", sym("...")) + V("FuncDef") + V("Table") + V(
    "SuffixedExpr"
  ),

  FuncCall = Cmt(V("SuffixedExpr"), function(s, i, exp)
    return exp.tag == "Call" or exp.tag == "Invoke", exp
  end),
  VarExpr = Cmt(V("SuffixedExpr"), function(s, i, exp)
    return exp.tag == "Id" or exp.tag == "Index", exp
  end),

  ---@diagnostic disable-next-line: redundant-parameter
  SuffixedExpr = Cf(V("PrimaryExpr") * (V("Index") + V("Call")) ^ 0, makeIndexOrCall),
  PrimaryExpr = V("Id") + tagC("Paren", sym("(") * expect(V("Expr"), "ExprParen") * expect(sym(")"), "CParenExpr")),
  Index = tagC("DotIndex", sym("." * -P(".")) * expect(V("StrId"), "NameIndex"))
    + tagC("ArrayIndex", sym("[" * -P(S("=["))) * expect(V("Expr"), "ExprIndex") * expect(sym("]"), "CBracketIndex")),
  Call = tagC("Invoke", Cg(sym(":" * -P(":")) * expect(V("StrId"), "NameMeth") * expect(V("FuncArgs"), "MethArgs")))
    + tagC("Call", V("FuncArgs")),

  FuncDef = kw("function") * V("FuncBody"),
  FuncArgs = sym("(") * commaSep(V("Expr"), "ArgList") ^ -1 * expect(sym(")"), "CParenArgs")
    + V("Table")
    + tagC("String", V("String")),

  Table = tagC("Table", sym("{") * V("FieldList") ^ -1 * expect(sym("}"), "CBraceTable")),
  FieldList = sepBy(V("Field"), V("FieldSep")) * V("FieldSep") ^ -1,
  Field = tagC("Pair", V("FieldKey") * expect(sym("="), "EqField") * expect(V("Expr"), "ExprField")) + V("Expr"),
  FieldKey = sym("[" * -P(S("=["))) * expect(V("Expr"), "ExprFKey") * expect(sym("]"), "CBracketFKey")
    + V("StrId") * #("=" * -P("=")),
  FieldSep = sym(",") + sym(";"),

  Id = tagC("Id", V("Name")),
  StrId = tagC("String", V("Name")),

  -- Lexer
  Skip = (V("Space") + V("Comment")) ^ 0,
  Space = space ^ 1,
  Comment = P("--") * V("LongStr") / function()
    return
  end + P("--") * (P(1) - P("\n")) ^ 0,

  Name = token(-V("Reserved") * C(V("Ident"))),
  Reserved = V("Keywords") * -V("IdRest"),
  Keywords = P("and")
    + "break"
    + "do"
    + "elseif"
    + "else"
    + "end"
    + "false"
    + "for"
    + "function"
    + "goto"
    + "if"
    + "in"
    + "local"
    + "nil"
    + "not"
    + "or"
    + "repeat"
    + "return"
    + "then"
    + "true"
    + "until"
    + "while",
  Ident = V("IdStart") * V("IdRest") ^ 0,
  IdStart = alpha + P("_"),
  IdRest = alnum + P("_"),

  Number = token((V("Hex") + V("Float") + V("Int")) / tonumber),
  Hex = (P("0x") + "0X") * expect(xdigit ^ 1, "DigitHex"),
  Float = V("Decimal") * V("Expo") ^ -1 + V("Int") * V("Expo"),
  Decimal = digit ^ 1 * "." * digit ^ 0 + P(".") * -P(".") * expect(digit ^ 1, "DigitDeci"),
  Expo = S("eE") * S("+-") ^ -1 * expect(digit ^ 1, "DigitExpo"),
  Int = digit ^ 1,

  String = token(V("ShortStr") + V("LongStr")),
  ShortStr = P('"') * Cs((V("EscSeq") + (P(1) - S('"\n'))) ^ 0) * expect(P('"'), "Quote")
    + P("'") * Cs((V("EscSeq") + (P(1) - S("'\n"))) ^ 0) * expect(P("'"), "Quote"),

  EscSeq = P("\\")
    / "" -- remove backslash
    * (
      P("a") / "\a"
      + P("b") / "\b"
      + P("f") / "\f"
      + P("n") / "\n"
      + P("r") / "\r"
      + P("t") / "\t"
      + P("v") / "\v"
      + P("\n") / "\n"
      + P("\r") / "\n"
      + P("\\") / "\\"
      + P('"') / '"'
      + P("'") / "'"
      + P("z") * space ^ 0 / ""
      + digit * digit ^ -2 / tonumber / string.char
      + P("x") * expect(C(xdigit * xdigit), "HexEsc") * Cc(16) / tonumber / string.char
      + P("u") * expect("{", "OBraceUEsc") * expect(C(xdigit ^ 1), "DigitUEsc") * Cc(16) * expect("}", "CBraceUEsc") / tonumber / utf8_char
      + throw("EscSeq")
    ),

  LongStr = V("Open") * C((P(1) - V("CloseEq")) ^ 0) * expect(V("Close"), "CloseLStr") / function(s, eqs)
    return s
  end,
  ---@diagnostic disable-next-line: redundant-parameter
  Open = "[" * Cg(V("Equals"), "openEq") * "[" * P("\n") ^ -1,
  Close = "]" * C(V("Equals")) * "]",
  Equals = P("=") ^ 0,
  CloseEq = Cmt(V("Close") * Cb("openEq"), function(s, i, closeEq, openEq)
    return #openEq == #closeEq
  end),

  OrOp = kw("or") / "or",
  AndOp = kw("and") / "and",
  RelOp = sym("~=") / "~=" + sym("==") / "==" + sym("<=") / "<=" + sym(">=") / ">=" + sym("<") / "<" + sym(">") / ">",
  BOrOp = sym("|") / "|",
  BXorOp = sym("~" * -P("=")) / "~",
  BAndOp = sym("&") / "&",
  ShiftOp = sym("<<") / "<<" + sym(">>") / ">>",
  ConcatOp = sym("..") / "..",
  AddOp = sym("+") / "+" + sym("-") / "-",
  MulOp = sym("*") / "*" + sym("//") / "//" + sym("/") / "/" + sym("%") / "%",
  UnaryOp = kw("not") / "not" + sym("-") / "-" + sym("#") / "#" + sym("~") / "~",
  PowOp = sym("^") / "^",
}

-- Helper function to calculate line number and column
local function calcline(subject, pos)
  if pos > #subject then
    pos = #subject
  end
  local line, linestart = 1, 1
  local newline, _ = string.find(subject, "\n", linestart)
  while newline and newline < pos do
    line = line + 1
    linestart = newline + 1
    newline, _ = string.find(subject, "\n", linestart)
  end
  return line, pos - linestart + 1
end

-- Create an error message for the input string
local function syntaxerror(errorinfo, pos, msg)
  local l, c = calcline(errorinfo.subject, pos)
  local error_msg = "%s:%d:%d: syntax error, %s"

  logger.error("Syntax error in source", {
    filename = errorinfo.filename or "input",
    line = l,
    column = c,
    position = pos,
    message = msg,
  })

  return string.format(error_msg, errorinfo.filename or "input", l, c, msg)
end

-- Parse a Lua source string
function M.parse(subject, filename)
  logger.debug("Parsing Lua source", {
    filename = filename or "input",
    subject_length = subject and #subject or 0,
  })

  local errorinfo = { subject = subject, filename = filename or "input" }

  -- Set a high max stack size to help with deeply nested tables and complex expressions
  -- This complements the 'cut' function in chainOp to prevent "subcapture nesting too deep" errors
  lpeg.setmaxstack(1000)

  logger.debug("Starting LPeg parse with max stack size 1000")
  ---@diagnostic disable-next-line: redundant-parameter
  local ast, label, errorpos = lpeg.match(G, subject, nil, errorinfo)

  if not ast then
    local errmsg = labels[label][2]
    local error_message = syntaxerror(errorinfo, errorpos, errmsg)

    logger.error("Parsing failed", {
      filename = filename or "input",
      error_label = labels[label][1],
      error_position = errorpos,
      error_message = errmsg,
    })

    return nil, error_message
  end

  logger.debug("Parsing completed successfully", {
    filename = filename or "input",
    ast_type = type(ast),
    has_ast = ast ~= nil,
  })

  return ast
end

return M
