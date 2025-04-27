--- Firmo Lua Parser Module
---
--- This module provides Lua code parsing using LPegLabel, AST validation,
--- AST pretty-printing, and code analysis capabilities.
--- Based on lua-parser by Andre Murbach Maidl (https://github.com/andremm/lua-parser).
---
--- @module lib.tools.parser
--- @author Andre Murbach Maidl (original), Firmo Team (adaptations)
--- @license MIT
--- @copyright 2023-2025 Firmo Team, Andre Murbach Maidl (original)
--- @version 1.0.0

---@class parser_module The public API of the Lua parser module.
---@field _VERSION string Module version.
---@field parse fun(source: string, name?: string): table|nil, string? Parses Lua code string into an AST. Returns AST table or nil, error_message.
---@field parse_file fun(file_path: string): table|nil, string? Parses a Lua file into an AST. Returns AST table or nil, error_message.
---@field validate fun(ast: table): boolean, string? Validates an AST structure. Returns true, nil or false, error_message.
---@field to_string fun(ast: table): string Converts an AST back to a human-readable string representation (using `pp.tostring`).
---@field get_executable_lines fun(ast: table, source: string): table Returns table mapping line numbers to true if executable.
---@field get_functions fun(ast: table, source: string): table Returns list of function definition info tables.
---@field create_code_map fun(source: string, name?: string): table|{error: string, valid: boolean} Creates a detailed code map (AST, lines, functions) from source. Returns code map or error table.
---@field create_code_map_from_file fun(file_path: string): table|{error: string, valid: boolean} Creates a detailed code map from a file. Returns code map or error table.

local M = {
  -- Module version
  _VERSION = "1.0.0",
}

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _logging, _fs

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

--- Get the filesystem module with lazy loading to avoid circular dependencies
---@return table|nil The filesystem module or nil if not available
local function get_fs()
  if not _fs then
    _fs = try_require("lib.tools.filesystem")
  end
  return _fs
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
    return logging.get_logger("parser")
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

get_logger().debug("LPegLabel loaded successfully", {
  module = "parser",
})

-- Import parser components
local parser = try_require("lib.tools.parser.grammar")
local pp = try_require("lib.tools.parser.pp")
local validator = try_require("lib.tools.parser.validator")

-- Utility functions for scope and position tracking
local scope_util = {
  --- Calculates line number and column from a 1-based character position in a string.
  ---@param subject string The source string.
  ---@param pos number The character position (1-based).
  ---@return number line Line number (1-based).
  ---@return number col Column number (1-based).
  ---@private
  lineno = function(subject, pos)
    if not subject or pos > #subject then
      pos = #subject or 0
    end
    local line, col = 1, 1
    for i = 1, pos do
      if subject:sub(i, i) == "\n" then
        line = line + 1
        col = 1
      else
        col = col + 1
      end
    end
    return line, col
  end,
}

--- Parse Lua code into an abstract syntax tree
---@param source string The Lua source code to parse
---@param name? string Optional name for the source (used in error messages).
---@return table|nil ast The abstract syntax tree table, or `nil` on error.
---@return string? error_message Error message string if parsing failed.
function M.parse(source, name)
  name = name or "input"

  get_logger().debug("Parsing Lua source", {
    source_name = name,
    source_length = source and #source or 0,
  })

  if type(source) ~= "string" then
    local error_msg = "Expected string source, got " .. type(source)
    get_logger().error("Invalid source type", {
      expected = "string",
      actual = type(source),
    })
    return nil, error_msg
  end

  -- Safety limit for source size INCREASED to 1MB
  if #source > 1024000 then -- 1MB limit
    local error_msg = "Source too large for parsing: " .. (#source / 1024) .. "KB"
    get_logger().error("Source size limit exceeded", {
      size_kb = (#source / 1024),
      limit_kb = 1024,
      source_name = name,
    })
    return nil, error_msg
  end

  -- Add timeout protection with INCREASED limits
  local start_time = os.clock()
  local MAX_PARSE_TIME = 10.0 -- 10 second timeout for parsing

  get_logger().debug("Starting parse with timeout protection", {
    timeout_seconds = MAX_PARSE_TIME,
    source_name = name,
  })

  -- Create a thread to handle parsing with timeout
  local co = coroutine.create(function()
    return parser.parse(source, name)
  end)

  -- Run the coroutine with timeout checks
  local status, result, error_msg

  while coroutine.status(co) ~= "dead" do
    -- Check if we've exceeded the time limit
    if os.clock() - start_time > MAX_PARSE_TIME then
      local timeout_error = "Parse timeout exceeded (" .. MAX_PARSE_TIME .. "s)"
      get_logger().error("Parse timeout", {
        timeout_seconds = MAX_PARSE_TIME,
        source_name = name,
        elapsed = os.clock() - start_time,
      })
      return nil, timeout_error
    end

    -- Resume the coroutine for a bit
    status, result, error_msg = coroutine.resume(co)

    -- If coroutine failed, return the error
    if not status then
      local parse_error = "Parser error: " .. tostring(result)
      get_logger().error("Parser coroutine failed", {
        error = tostring(result),
        source_name = name,
      })
      return nil, parse_error
    end

    -- Brief yield to allow other processes
    if coroutine.status(co) ~= "dead" then
      coroutine.yield()
    end
  end

  -- Check the parse result
  local ast = result
  if not ast then
    get_logger().error("Parse returned no AST", {
      error = error_msg or "Unknown parse error",
      source_name = name,
    })
    return nil, error_msg or "Parse error"
  end

  -- Verify the AST is a valid table to avoid crashes
  if type(ast) ~= "table" then
    get_logger().error("Invalid AST type", {
      expected = "table",
      actual = type(ast),
      source_name = name,
    })
    return nil, "Invalid AST returned (not a table)"
  end

  get_logger().debug("Successfully parsed Lua source", {
    source_name = name,
    parse_time = os.clock() - start_time,
  })

  return ast
end

--- Parse a Lua file into an abstract syntax tree
---@param file_path string Path to the Lua file to parse.
---@return table|nil ast The abstract syntax tree table, or `nil` on error.
---@return string? error_message Error message string if reading or parsing failed.
function M.parse_file(file_path)
  get_logger().debug("Parsing Lua file", {
    file_path = file_path,
  })

  if not get_fs().file_exists(file_path) then
    get_logger().error("File not found for parsing", {
      file_path = file_path,
    })
    return nil, "File not found: " .. file_path
  end

  local source, read_error = get_fs().read_file(file_path)
  if not source then
    get_logger().error("Failed to read file for parsing", {
      file_path = file_path,
      error = read_error or "Unknown read error",
    })
    return nil, "Failed to read file: " .. file_path
  end

  get_logger().debug("File read successfully for parsing", {
    file_path = file_path,
    source_length = #source,
  })

  return M.parse(source, file_path)
end

--- Converts an AST to a human-readable string representation using the pretty-printer.
---@param ast table The abstract syntax tree table.
---@return string representation String representation of the AST. Returns "Not a valid AST" if input is invalid.
function M.to_string(ast)
  if type(ast) ~= "table" then
    return "Not a valid AST"
  end

  return pp.tostring(ast)
end

--- Validate that an AST is properly structured
---@param ast table The abstract syntax tree to validate
--- Validates that an AST is properly structured using the validator module.
---@param ast table The abstract syntax tree table to validate.
---@return boolean is_valid `true` if the AST is valid, `false` otherwise.
---@return string? error_message Error message string if validation failed.
function M.validate(ast)
  if type(ast) ~= "table" then
    return false, "Not a valid AST"
  end

  local ok, err = validator.validate(ast)
  return ok, err
end

--- Helper to determine if an AST node tag represents an executable statement.
--- Excludes structural/control flow nodes like If, Block, Function, Label.
---@param tag string Node tag (e.g., "Set", "Call", "If").
---@return boolean `true` if the node type is considered executable, `false` otherwise.
---@private
local function is_executable_node(tag)
  -- Control flow statements and structural elements are not directly executable
  local non_executable = {
    ["If"] = true,
    ["Block"] = true,
    ["While"] = true,
    ["Repeat"] = true,
    ["Fornum"] = true,
    ["Forin"] = true,
    ["Function"] = true,
    ["Label"] = true,
  }

  return not non_executable[tag]
end

--- Recursive helper to traverse an AST and identify executable lines.
--- Populates the `lines` table with line numbers corresponding to executable nodes.
---@param node table The current AST node being processed.
---@param lines table Output table where keys are executable line numbers and values are `true`.
---@param source_lines string The original source code (used by `scope_util.lineno`).
---@private
local function process_node_for_lines(node, lines, source_lines)
  if not node or type(node) ~= "table" then
    return
  end

  local tag = node.tag
  if not tag then
    return
  end

  -- Record the position of this node if it has one
  if node.pos and node.end_pos and is_executable_node(tag) then
    local start_line, _ = scope_util.lineno(source_lines, node.pos)
    local end_line, _ = scope_util.lineno(source_lines, node.end_pos)

    for line = start_line, end_line do
      lines[line] = true
    end
  end

  -- Process child nodes
  for i, child in ipairs(node) do
    if type(child) == "table" then
      process_node_for_lines(child, lines, source_lines)
    end
  end
end

--- Get a list of executable lines from a Lua AST
---@param ast table The abstract syntax tree
---@param source string The original source code
---@param source string The original source code (required for accurate line mapping).
---@return table executable_lines Table mapping line numbers (number) to `true` for lines containing executable code.
function M.get_executable_lines(ast, source)
  if type(ast) ~= "table" then
    return {}
  end

  local lines = {}
  process_node_for_lines(ast, lines, source or "")

  return lines
end

--- Helper to check if an AST node represents a function definition.
---@param node table AST node to check.
---@return boolean `true` if the node tag is "Function".
---@private
local function is_function_node(node)
  return node and node.tag == "Function"
end

--- Helper to extract structured information about a function definition from its AST node.
---@param node table The "Function" AST node.
---@param source string The original source code (for line numbers).
---@param parent_name? string The name assigned to the function (from parent AST nodes), defaults to "anonymous".
---@return table|nil func_info A table containing `{ name, params = {}, is_vararg, line_start, line_end, pos, end_pos }`, or `nil` if `node` is not a function node.
---@private
local function get_function_info(node, source, parent_name)
  if not is_function_node(node) then
    return nil
  end

  local func_info = {
    pos = node.pos,
    end_pos = node.end_pos,
    name = parent_name or "anonymous",
    is_method = false,
    params = {},
    is_vararg = false,
    line_start = 0,
    line_end = 0,
  }

  -- Get line range
  if source and node.pos then
    func_info.line_start, _ = scope_util.lineno(source, node.pos)
    func_info.line_end, _ = scope_util.lineno(source, node.end_pos)
  end

  -- Process parameter list
  if node[1] then
    for i, param in ipairs(node[1]) do
      if param.tag == "Id" then
        table.insert(func_info.params, param[1])
      elseif param.tag == "Dots" then
        func_info.is_vararg = true
      end
    end
  end

  return func_info
end

--- Recursive helper to traverse an AST and find all function definitions.
--- Handles `Function`, `Localrec`, and `Set` nodes that define functions.
--- Populates the `functions` table with info extracted by `get_function_info`.
---@param node table The current AST node being processed.
---@param functions table Output table to store extracted function info tables.
---@param source string The original source code.
---@param parent_name? string Name context from the parent node (used for assignment-based function names).
---@private
local function process_node_for_functions(node, functions, source, parent_name)
  if not node or type(node) ~= "table" then
    return
  end

  local tag = node.tag
  if not tag then
    return
  end

  -- Handle function definitions
  if tag == "Function" then
    local func_info = get_function_info(node, source, parent_name)
    if func_info then
      table.insert(functions, func_info)
    end
  elseif tag == "Localrec" and node[2] and node[2][1] and node[2][1].tag == "Function" then
    -- Handle local function declaration: local function foo()
    local name = node[1][1][1] -- Extract name from the Id node
    local func_info = get_function_info(node[2][1], source, name)
    if func_info then
      table.insert(functions, func_info)
    end
  elseif tag == "Set" and node[2] and node[2][1] and node[2][1].tag == "Function" then
    -- Handle global/table function assignment: function foo() or t.foo = function()
    local name = "anonymous"
    if node[1] and node[1][1] then
      if node[1][1].tag == "Id" then
        name = node[1][1][1]
      elseif node[1][1].tag == "Index" then
        -- Handle table function assignment
        local t_name = node[1][1][1][1] or "table"
        local f_name = node[1][1][2][1] or "method"
        name = t_name .. "." .. f_name
      end
    end
    local func_info = get_function_info(node[2][1], source, name)
    if func_info then
      table.insert(functions, func_info)
    end
  end

  -- Process child nodes
  for i, child in ipairs(node) do
    if type(child) == "table" then
      process_node_for_functions(child, functions, source, parent_name)
    end
  end
end

--- Get a list of functions and their positions from a Lua AST
---@param ast table The abstract syntax tree
---@param source string The original source code
---@param source string The original source code (required for accurate line mapping).
---@return table functions An array of function info tables (structure described in `get_function_info` return).
function M.get_functions(ast, source)
  if type(ast) ~= "table" then
    return {}
  end

  local functions = {}
  process_node_for_functions(ast, functions, source or "")

  return functions
end

--- Create a detailed map of a Lua source code file including AST, executable lines, and functions
---@param source string The Lua source code
---@param name? string Optional name for the source (for error messages)
---@return table|nil code_map The code map containing AST and analysis, or nil on error
---@param name? string Optional name for the source (for error messages).
---@return table|{error: string, valid: boolean} code_map The code map `{ source, ast, lines, source_lines, executable_lines, functions, valid }`, or an error table `{ error, valid=false }`.
function M.create_code_map(source, name)
  name = name or "input"

  get_logger().debug("Creating code map from source", {
    source_name = name,
    source_length = source and #source or 0,
  })

  -- Parse the source
  local ast, err = M.parse(source, name)
  if not ast then
    get_logger().error("Failed to parse source for code map", {
      source_name = name,
      error = err,
    })
    return {
      error = err,
      source = source,
      lines = {},
      functions = {},
      valid = false,
    }
  end

  -- Split source into lines
  local lines = {}
  for line in source:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  get_logger().debug("Source split into lines", {
    source_name = name,
    line_count = #lines,
  })

  -- Get executable lines
  local executable_lines = M.get_executable_lines(ast, source)

  -- Count executable lines for logging
  local executable_count = 0
  for _ in pairs(executable_lines) do
    executable_count = executable_count + 1
  end

  -- Get functions
  local functions = M.get_functions(ast, source)

  get_logger().debug("Code analysis complete", {
    source_name = name,
    executable_lines = executable_count,
    function_count = #functions,
  })

  -- Build the code map
  local code_map = {
    source = source,
    ast = ast,
    lines = lines,
    source_lines = #lines,
    executable_lines = executable_lines,
    functions = functions,
    valid = true,
  }

  return code_map
end

--- Create a detailed map of a Lua file including AST, executable lines, and functions
---@param file_path string Path to the Lua file
---@return table|nil code_map The code map containing AST and analysis, or nil on error
---@return table|{error: string, valid: boolean} code_map The code map containing AST and analysis, or an error table `{ error, valid=false }`.
function M.create_code_map_from_file(file_path)
  get_logger().debug("Creating code map from file", {
    file_path = file_path,
  })

  if not get_fs().file_exists(file_path) then
    get_logger().error("File not found for code map creation", {
      file_path = file_path,
    })
    return {
      error = "File not found: " .. file_path,
      valid = false,
    }
  end

  local source, read_error = get_fs().read_file(file_path)
  if not source then
    get_logger().error("Failed to read file for code map creation", {
      file_path = file_path,
      error = read_error or "Unknown read error",
    })
    return {
      error = "Failed to read file: " .. file_path,
      valid = false,
    }
  end

  get_logger().debug("File read successfully for code map creation", {
    file_path = file_path,
    source_length = #source,
  })

  local code_map = M.create_code_map(source, file_path)

  get_logger().debug("Code map created", {
    file_path = file_path,
    valid = code_map.valid,
    executable_lines = code_map.executable_lines and table.concat(
      (function()
        local keys = {}
        for k, _ in pairs(code_map.executable_lines) do
          table.insert(keys, tostring(k))
        end
        return keys
      end)(),
      ","
    ),
    function_count = code_map.functions and #code_map.functions or 0,
  })

  return code_map
end

return M
