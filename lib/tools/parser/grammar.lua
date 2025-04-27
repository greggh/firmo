--- LPeg Grammar for Lua 5.3/5.4 Parser
---
--- This module implements a parser for Lua 5.3/5.4 using LPegLabel,
--- generating an Abstract Syntax Tree (AST).
--- Based on lua-parser by Andre Murbach Maidl (https://github.com/andremm/lua-parser).
---
--- @module lib.tools.parser.grammar
--- @author Andre Murbach Maidl (original), Firmo Team (adaptations)
--- @license MIT
--- @copyright 2023-2025 Firmo Team, Andre Murbach Maidl (original)
--- @version 1.0.0

---@class parser.grammar The API for the Lua grammar parser.
---@field _VERSION string Module version.
---@field parse fun(subject: string, filename?: string): table|nil, string? Parses a Lua code string into an AST table. Returns `ast_table, nil` on success, or `nil, error_message` on syntax error.

local M = {
  -- Module version
  _VERSION = "1.0.0",
}

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _logging

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

--- Get the logging module with lazy loading to avoid circular dependencies
---@return table|nil The logging module or nil if not available
local function get_logging()
  if not _logging then
    _logging = try_require("lib.tools.logging")
  end
  return _logging
end

--- Get a logger instance for this module
---@return table A logger instance (either real or stub)
local function get_logger()
  local logging = get_logging()
  if logging then
    return logging.get_logger("grammar")
  end
  -- Return a stub logger if logging module isn't available
  return {
    error = function(msg)
      print("[ERROR] " .. msg)
    end,
    warn = function(msg)
      print("[WARN] " .. msg)
    end,
    info = function(msg)
      print("[INFO] " .. msg)
    end,
    debug = function(msg)
      print("[DEBUG] " .. msg)
    end,
    trace = function(msg)
      print("[TRACE] " .. msg)
    end,
  }
end

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

--- Mapping of internal error labels to user-friendly error messages.
---@private
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

--- Generates an LPeg error pattern (`T(index)`).
--- Finds the index corresponding to the `Err` + `label` key in the `labels` table.
---@param label string Error label suffix (e.g., "Extra", "InvalidStat").
---@return table LPeg error pattern `T(i)`.
---@private
---@throws error If the combined label (`Err` + `label`) is not found in the `labels` table.
local function throw(label)
  label = "Err" .. label
  get_logger().debug("Throwing syntax error", {
    label = label,
  })

  for i, labelinfo in ipairs(labels) do
    if labelinfo[1] == label then
      return T(i)
    end
  end

  get_logger().error("Error label not found", {
    requested_label = label,
  })

  error("Label not found: " .. label)
end

--- Creates an LPeg pattern that expects `patt`, otherwise throws error `label`.
--- Equivalent to `patt + throw(label)`.
---@param patt table LPeg pattern to expect.
---@param label string Error label suffix to throw if `patt` doesn't match.
---@return table LPeg pattern.
---@private
local function expect(patt, label)
  return patt + throw(label)
end

--- Creates an LPeg pattern that matches `patt` followed by optional whitespace/comments (`V("Skip")`).
--- Used for matching tokens like identifiers, numbers, strings, symbols.
---@param patt table LPeg pattern representing the core token.
---@return table LPeg pattern for the token including optional skip pattern.
---@private
local function token(patt)
  return patt * V("Skip")
end

--- Creates an LPeg pattern for a specific symbol (e.g., "(", ")", ",", "=").
--- Uses `token()` to handle surrounding whitespace/comments.
---@param str string The symbol string.
---@return table LPeg pattern for the symbol token.
---@private
local function sym(str)
  return token(P(str))
end

--- Creates an LPeg pattern for a specific keyword (e.g., "if", "then", "end").
--- Ensures the keyword is not followed by identifier characters (`V("IdRest")`) to avoid matching prefixes of identifiers.
---@param str string The keyword string.
---@return table LPeg pattern for the keyword token.
---@private
local function kw(str)
  return token(P(str) * -V("IdRest"))
end

--- Simple decrement function for use with LPeg position captures (`Cp()`).
---@param n number The number (position) to decrement.
---@return number n-1.
---@private
local function dec(n)
  return n - 1
end

--- Creates an LPeg pattern that captures a structure tagged with `tag` and includes start (`pos`) and end (`end_pos`) positions.
--- Uses `Ct` to create a table, `Cg` to capture groups named `pos`, `tag`, the `patt` result, and `end_pos`.
---@param tag string The tag name for the captured structure (e.g., "Block", "If", "Number").
---@param patt table The LPeg pattern to capture.
---@return table LPeg capture pattern generating `{ tag = tag, pos = start_pos, ...patt_results..., end_pos = end_pos }`.
---@private
local function tagC(tag, patt)
  ---@diagnostic disable-next-line: redundant-parameter
  return Ct(Cg(Cp(), "pos") * Cg(Cc(tag), "tag") * patt * Cg(Cp() / dec, "end_pos"))
end

--- Creates an AST node table for a unary operation.
---@param op string The unary operator (e.g., "not", "-", "#").
---@param e table The operand expression AST node.
---@return table The unary operation AST node: `{ tag = "Op", pos, end_pos, [1] = op, [2] = e }`.
---@private
local function unaryOp(op, e)
  return { tag = "Op", pos = e.pos, end_pos = e.end_pos, [1] = op, [2] = e }
end

--- Creates an AST node table for a binary operation, handling left-associativity.
--- If `op` is nil, it means only one operand was parsed, so it returns that operand directly.
---@param e1 table The left operand expression AST node.
---@param op string|nil The binary operator (e.g., "+", "-", "and") or nil if no operator followed `e1`.
---@param e2 table|nil The right operand expression AST node (only present if `op` is not nil).
---@return table The binary operation AST node `{ tag = "Op", pos, end_pos, [1] = op, [2] = e1, [3] = e2 }`, or just `e1` if `op` is nil.
---@private
local function binaryOp(e1, op, e2)
  if not op then
    return e1
  else
    return { tag = "Op", pos = e1.pos, end_pos = e2.end_pos, [1] = op, [2] = e1, [3] = e2 }
  end
end

--- Creates an LPeg pattern for a list of `patt` separated by `sep`.
--- Captures the elements into a sequence table. Expects `patt` after each `sep`.
---@param patt table LPeg pattern for the list element.
---@param sep table LPeg pattern for the separator.
---@param label? string Optional error label suffix to throw if `patt` is missing after `sep`.
---@return table LPeg pattern capturing a sequence of elements.
---@private
local function sepBy(patt, sep, label)
  if label then
    return patt * Cg(sep * expect(patt, label)) ^ 0
  else
    return patt * Cg(sep * patt) ^ 0
  end
end

--- LPeg capture function used with `Cmt` to prevent excessive subcapture nesting errors
--- by effectively "cutting" the capture history at this point. Used in `chainOp`.
---@param s string The subject string (unused).
---@param idx number The current position.
---@param match any The captured value.
---@return number idx The current position.
---@return any match The captured value.
---@private
local function cut(s, idx, match)
  return idx, match
end

--- Creates an LPeg pattern for left-associative binary operators.
--- Uses `sepBy` to match operands (`patt`) separated by operators (`sep`),
--- folds the results using `binaryOp`, and uses `cut` to prevent deep nesting errors.
---@param patt table LPeg pattern for the operands.
---@param sep table LPeg pattern for the operators.
---@param label? string Optional error label suffix if operand is missing after operator.
---@return table LPeg pattern that generates a nested binary operation AST.
---@private
local function chainOp(patt, sep, label)
  ---@diagnostic disable-next-line: redundant-parameter
  return Cmt(Cf(sepBy(patt, sep, label), binaryOp), cut)
end

--- Creates an LPeg pattern for a comma-separated list of `patt`.
--- Uses `sepBy` with a comma symbol.
---@param patt table LPeg pattern for the list element.
---@param label? string Optional error label suffix if element is missing after comma.
---@return table LPeg pattern capturing a sequence of elements.
---@private
local function commaSep(patt, label)
  return sepBy(patt, sym(","), label)
end

--- Tags a captured block AST node (from a `do...end` statement) with the "Do" tag.
---@param block table The captured block AST node.
---@return table The modified block AST node with `tag = "Do"`.
---@private
local function tagDo(block)
  block.tag = "Do"
  return block
end

--- Adjusts the AST for a function statement (`FuncStat`) or local function (`LocalFunc`).
--- Inserts "self" as the first parameter if it's a method definition (`:name`).
--- Wraps the function name and parameters list in extra tables for consistent AST structure.
---@param func table The raw function AST captured by `FuncStat` or `LocalFunc`.
---@return table The adjusted function AST node.
---@private
local function fixFuncStat(func)
  if func[1].is_method then
    table.insert(func[2][1], 1, { tag = "Id", [1] = "self" })
  end
  func[1] = { func[1] }
  func[2] = { func[2] }
  return func
end

--- Adds the "..." (varargs) AST node to the parameter list if present.
---@param params table The table of parameter AST nodes.
---@param dots? table The optional "..." AST node.
---@return table params The potentially modified parameter list.
---@private
local function addDots(params, dots)
  if dots then
    table.insert(params, dots)
  end
  return params
end

--- Creates an AST node for an index operation (e.g., `t.field`, `t["key"]`).
--- Used when folding dot-separated names in `FuncName`.
---@param t table The table/prefix expression AST node.
---@param index table The index expression AST node (usually a "String" tag).
---@return table The index operation AST node: `{ tag = "Index", pos, end_pos, [1] = t, [2] = index }`.
---@private
local function insertIndex(t, index)
  return { tag = "Index", pos = t.pos, end_pos = index.end_pos, [1] = t, [2] = index }
end

--- Creates an AST node for a method name in a function definition (`function obj:name(...)`).
--- Marks the node with `is_method = true` for later processing (adding "self").
---@param t table The table/prefix expression AST node (object).
---@param method table|nil The method name AST node (usually "String") or nil if not a method definition.
---@return table The original `t` node, or a new "Index" node marked as a method: `{ tag = "Index", pos, end_pos, is_method = true, [1] = t, [2] = method }`.
---@private
local function markMethod(t, method)
  if method then
    return { tag = "Index", pos = t.pos, end_pos = method.end_pos, is_method = true, [1] = t, [2] = method }
  end
  return t
end

--- Combines a primary expression (`t1`) with a suffix (`t2`) which can be an index (`.`, `[]`), a call (`()`, `{}`), or a method call (`:`).
--- Constructs the appropriate AST node ("Index", "Call", "Invoke").
---@param t1 table The base expression AST node (e.g., variable, function call).
---@param t2 table The suffix AST node (e.g., from `Index` or `Call` rules).
---@return table The combined AST node.
---@private
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
--- Calculates the line number and column for a given character position in a string.
---@param subject string The source code string.
---@param pos number The character position (1-based).
---@return number line Line number (1-based).
---@return number col Column number (1-based).
---@private
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

--- Formats a syntax error message including filename, line, column, and the specific error detail.
--- Also logs the error using the module's get_logger().
---@param errorinfo {subject: string, filename: string} Table containing the source string and filename.
---@param pos number The character position (1-based) where the error occurred.
---@param msg string The specific error message detail (from the `labels` table).
---@return string The fully formatted error message string.
---@private
local function syntaxerror(errorinfo, pos, msg)
  local l, c = calcline(errorinfo.subject, pos)
  local error_msg = "%s:%d:%d: syntax error, %s"

  get_logger().error("Syntax error in source", {
    filename = errorinfo.filename or "input",
    line = l,
    column = c,
    position = pos,
    message = msg,
  })

  return string.format(error_msg, errorinfo.filename or "input", l, c, msg)
end

--- Parses a Lua source code string into an Abstract Syntax Tree (AST).
---@param subject string The Lua code to parse.
---@param filename? string Optional filename to use in error messages (defaults to "input").
---@return table|nil ast The generated AST table on success, or `nil` on failure.
---@return string? error_message An error message string if parsing failed, `nil` otherwise.
function M.parse(subject, filename)
  get_logger().debug("Parsing Lua source", {
    filename = filename or "input",
    subject_length = subject and #subject or 0,
  })

  local errorinfo = { subject = subject, filename = filename or "input" }

  -- Set a high max stack size to help with deeply nested tables and complex expressions
  -- This complements the 'cut' function in chainOp to prevent "subcapture nesting too deep" errors
  lpeg.setmaxstack(1000)

  get_logger().debug("Starting LPeg parse with max stack size 1000")
  ---@diagnostic disable-next-line: redundant-parameter
  local ast, label, errorpos = lpeg.match(G, subject, nil, errorinfo)

  if not ast then
    local errmsg = labels[label][2]
    local error_message = syntaxerror(errorinfo, errorpos, errmsg)

    get_logger().error("Parsing failed", {
      filename = filename or "input",
      error_label = labels[label][1],
      error_position = errorpos,
      error_message = errmsg,
    })

    return nil, error_message
  end

  get_logger().debug("Parsing completed successfully", {
    filename = filename or "input",
    ast_type = type(ast),
    has_ast = ast ~= nil,
  })

  return ast
end

return M
