-- firmo v3 coverage instrumentation module
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")
local parser = require("lib.coverage.v3.instrumentation.parser")
local transformer = require("lib.coverage.v3.instrumentation.transformer")
local sourcemap = require("lib.coverage.v3.instrumentation.sourcemap")
local path_mapping = require("lib.coverage.v3.path_mapping")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.instrumentation")

---@class coverage_v3_instrumentation
---@field instrument_file fun(file_path: string): table|nil, string? Instrument a Lua file with coverage tracking
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0"
}

-- Create temp directory for instrumented files if needed
local temp_dir
local function ensure_temp_dir()
  if not temp_dir then
    temp_dir = test_helper.create_temp_test_directory()
    -- Create instrumented subdirectory
    fs.create_directory(fs.join_paths(temp_dir.path, "instrumented"))
  end
  return temp_dir
end

-- Get path for instrumented version of a file
local function get_instrumented_path(original_path)
  local dir = ensure_temp_dir()
  local filename = fs.basename(original_path)
  local subdirs = fs.dirname(original_path):gsub("^/", "")
  
  -- Create subdirectories if needed
  if subdirs ~= "" then
    local full_path = fs.join_paths(dir.path, "instrumented", subdirs)
    fs.create_directory(full_path)
  end
  
  return fs.join_paths(dir.path, "instrumented", subdirs, filename)
end

-- Instrument a Lua file with coverage tracking
---@param file_path string Path to the Lua file to instrument
---@return table|nil result Result containing instrumented_path and source_map, or nil on error
---@return string? error Error message if instrumentation failed
function M.instrument_file(file_path)
  -- Validate input
  if not file_path or type(file_path) ~= "string" then
    return nil, error_handler.validation_error(
      "Invalid file path",
      { path = file_path }
    )
  end

  -- Read source file
  local source, read_err = fs.read_file(file_path)
  if not source then
    return nil, error_handler.io_error(
      "Failed to read source file",
      { path = file_path, error = read_err }
    )
  end

  logger.debug("Instrumenting file", {
    path = file_path,
    source_length = #source
  })

  -- Parse source into AST
  local ast, parse_err = parser.parse(source)
  if not ast then
    return nil, error_handler.validation_error(
      "Failed to parse source code",
      { error = parse_err }
    )
  end

  -- Transform AST with tracking calls
  local transformed_ast, source_map = transformer.transform(ast)
  if not transformed_ast then
    return nil, error_handler.validation_error(
      "Failed to transform AST",
      { error = "AST transformation failed" }
    )
  end

  -- Generate instrumented code
  local instrumented_code = transformer.generate(transformed_ast)
  if not instrumented_code then
    return nil, error_handler.validation_error(
      "Failed to generate instrumented code",
      { error = "Code generation failed" }
    )
  end

  -- Get path for instrumented file
  local instrumented_path = get_instrumented_path(file_path)

  -- Write instrumented code to temp file
  local success, write_err = fs.write_file(instrumented_path, instrumented_code)
  if not success then
    return nil, error_handler.io_error(
      "Failed to write instrumented file",
      { path = instrumented_path, error = write_err }
    )
  end

  -- Register temp file for cleanup
  test_helper.register_temp_file(instrumented_path)

  -- Create source map
  local map = sourcemap.create(file_path, source, instrumented_code)
  if not map then
    return nil, error_handler.validation_error(
      "Failed to create source map",
      { error = "Source map creation failed" }
    )
  end

  -- Register path mapping
  path_mapping.register_path_pair(file_path, instrumented_path)

  logger.debug("File instrumented successfully", {
    original_path = file_path,
    instrumented_path = instrumented_path
  })

  return {
    instrumented_path = instrumented_path,
    source_map = map
  }
end

return M