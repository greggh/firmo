---@class TestHelper The public API for the test helper module.
---@field with_error_capture fun(func: function): function Wraps a function to safely capture errors. The wrapper function returns `result, nil` on success, `nil, error_object` on failure. @throws table Re-throws unexpected errors from `pcall` if error handler integration fails.
---@field expect_error fun(func: function, message_pattern?: string): table Throws an assertion error if `func` does not throw an error, or if the error message doesn't match `message_pattern`. Returns the captured error object if requirements met. @throws table If the function `fn` does not throw, or if the error message does not match `message_pattern`.
---@field create_temp_test_directory fun(): TestDirectory Creates a temporary test directory with helper methods. @throws table If directory creation fails.
---@field with_temp_test_directory fun(files_map: table<string, string>, callback: fun(dir_path: string, files: string[], test_dir: TestDirectory): any): any Creates a directory with predefined files, runs `callback`, and ensures cleanup. Returns callback results. @throws table If directory/file creation fails or if `callback` throws.
---@field register_temp_file fun(file_path: string): boolean Registers a file for automatic cleanup via `temp_file`.
---@field register_temp_directory fun(dir_path: string): boolean Registers a directory for automatic cleanup via `temp_file`.
---@field execute_string fun(code: string): any|nil, string? Executes a string of Lua code using `load()`. Returns results or `nil, error_message`.
---@field expect_async_error fun(async_fn: function, timeout_ms: number, message_pattern?: string): table Asserts that an async function throws an error within a timeout, optionally matching the message. Returns the error object. @throws table If the function succeeds, times out, or the message doesn't match.
---@field with_isolated_module_run fun(module_name: string, setup_fn: function|nil, run_fn: function, ...):boolean,any Calls run_fn with a freshly required module, after setup_fn. Returns success flag and results or error object.
--- Firmo Test Helper Module
---
--- This module provides utility functions specifically designed to simplify writing
--- tests within the Firmo framework, particularly for error handling scenarios
--- and managing temporary files/directories during tests.
---
--- Usage examples:
---
--- 1. Using `with_error_capture` to safely test functions that throw errors:
---    ```lua
---    -- This captures errors and returns them as structured objects
---    local result, err = test_helper.with_error_capture(function()
---      some_function_that_throws()
---    end)()
---    expect(err).to.exist()
---    expect(err.message).to.match("expected error message")
---    ```
---
--- 2. Using `expect_error` to verify a function throws an error with a specific message:
---    ```lua
---    local err = test_helper.expect_error(fails_with_message, "expected error")
---    ```
---
--- 3. Using `create_temp_test_directory` and `with_temp_test_directory`:
---    ```lua
---    local test_dir = test_helper.create_temp_test_directory()
---    test_dir:create_file("config.json", '{"setting": "value"}')
---
---    test_helper.with_temp_test_directory({
---      ["data.txt"] = "test data"
---    }, function(dir_path, files, test_dir)
---      -- Test code using dir_path...
---    end)
---    ```
---
--- @module lib.tools.test_helper
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0

local inspect = require("inspect")

--- Returns the name of the current test from debug information
---@return string name The name of the test based on the debug info, or "unknown" if not available
local function get_test_name()
  local info = debug.getinfo(3, "n")
  return info.name or "unknown"
end

--- Returns the location (file:line) of the current test from debug information
---@return string location The source location of the test in "file:line" format
local function get_test_location()
  local info = debug.getinfo(3, "Sl")
  return info.source .. ":" .. info.currentline
end

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler, _fs, _async, _logging -- Add _logging

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

--- Get the success handler module with lazy loading to avoid circular dependencies
---@return table|nil The error handler module or nil if not available
local function get_error_handler()
  if not _error_handler then
    _error_handler = try_require("lib.tools.error_handler")
  end
  return _error_handler
end

--- Get the async module with lazy loading
---@return table|nil The async module or nil if not available
local function get_async()
  if not _async then
    _async = try_require("lib.async")
  end
  return _async
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
    return logging.get_logger("TestHelper")
  end
  -- Return a stub logger if logging module isn't available
  return {
    error = function(msg, ctx)
      print("[ERROR] TestHelper: " .. msg, ctx)
    end,
    warn = function(msg, ctx)
      print("[WARN] TestHelper: " .. msg, ctx)
    end,
    info = function(msg, ctx)
      print("[INFO] TestHelper: " .. msg, ctx)
    end,
    debug = function(msg, ctx)
      print("[DEBUG] TestHelper: " .. msg, ctx)
    end,
    trace = function(msg, ctx)
      print("[TRACE] TestHelper: " .. msg, ctx)
    end,
  }
end

local temp_file = try_require("lib.tools.filesystem.temp_file")

local helper = {}

-- Compatibility function for table unpacking
local unpack_table = table.unpack or _G.unpack -- More robust for Lua 5.1 if global 'unpack' is removed/nil

--- Wraps a function to safely capture any errors it throws.
--- Sets the error handler's test context to expect errors, runs the function via `pcall`,
--- processes the captured error into a standardized `TEST_EXPECTED` error object,
--- and clears the test context.
---@param fn function The function to wrap.
---@return function wrapper A new function that, when called, executes `fn` and returns `result, nil` on success or `nil, error_object` on failure.
---@throws table Re-throws errors from `pcall` if error processing itself fails critically.
function helper.with_error_capture(fn) -- Removed options, was unused by simplified logic
  assert(type(fn) == "function", "Expected function for with_error_capture")
  local eh = get_error_handler() -- Ensure error_handler is available
  local logger_instance = get_logger() -- Get logger instance

  return function(...)
    -- No longer setting/clearing test_metadata here as it's complex and
    -- should be managed by the test runner or expect_error itself if needed.

    local pcall_results = { pcall(fn, ...) }
    local pcall_success = table.remove(pcall_results, 1) -- True if fn completed without Lua error

    if not pcall_success then
      -- Case 1: fn itself threw a Lua error.
      -- pcall_results[1] is the error message/object from Lua.
      local thrown_err_val = pcall_results[1]
      logger_instance.debug("with_error_capture: fn threw an error", { error = thrown_err_val })
      local err_obj = eh.test_expected_error( -- Use test_expected_error for consistency
        (type(thrown_err_val) == "string" and thrown_err_val or "Function threw an error"),
        { original_error_type = type(thrown_err_val), source = "pcall_direct_error" },
        (type(thrown_err_val) == "table" and thrown_err_val or nil) -- cause
      )
      return nil, err_obj
    end

    -- Case 2: fn completed, pcall_results contains its return values.
    -- Example: json.decode failing returns (nil, "error_string")
    -- So, pcall_results would be {nil, "error_string"}
    local fn_first_return = pcall_results[1]
    local fn_second_return = pcall_results[2] -- Might be nil if fn returned only one value

    if fn_first_return == nil and fn_second_return ~= nil then
      -- fn indicated an error by returning (nil, error_val).
      -- Normalize fn_second_return into a standard error object.
      logger_instance.debug(
        "with_error_capture: fn returned (nil, error_val)",
        { error_val_type = type(fn_second_return) }
      )
      if eh.is_error(fn_second_return) then -- It's already a standard error object
        return nil, fn_second_return
      elseif type(fn_second_return) == "string" then -- It's an error string
        return nil, eh.test_expected_error(fn_second_return, { source_fn_returned_string_error = true })
      else
        -- fn returned (nil, some_other_non_error_type_value).
        -- This is treated as a successful return of (nil, other_val).
        logger_instance.debug(
          "with_error_capture: fn returned (nil, non_error_value), passing through.",
          { results_count = #pcall_results }
        )
        return unpack_table(pcall_results) -- Contains original (nil, other_val, ...)
      end
    end

    -- If fn succeeded and didn't return the (nil, error_indicator) pattern, pass through all its results.
    logger_instance.debug(
      "with_error_capture: fn succeeded, passing through results.",
      { results_count = #pcall_results }
    )
    return unpack_table(pcall_results)
  end
end

--- Asserts that a function throws an error, optionally matching a pattern.
--- Sets the error handler context to expect an error, runs the function via `pcall`,
--- and throws a test assertion error if the function *doesn't* throw or if the message doesn't match.
---@param fn function The function expected to throw an error.
---@param message_pattern? string Optional Lua pattern to match against the error message.
---@return table error The captured error object if the function threw an error as expected and the message matched (if provided).
---@throws table If the function `fn` does not throw, or if `message_pattern` is provided and the error message does not match.
function helper.expect_error(fn, message_pattern, options)
  options = options or {}
  -- Set up test expectation context
  -- Extract useful data for building test result context:
  local test_name = get_test_name()
  local test_location = get_test_location()
  local caller_info = debug.getinfo(2, "Sl")
  get_error_handler().set_current_test_metadata({
    name = test_name,
    expect_error = true,
    caller_info = caller_info,
    function_info = debug.getinfo(fn, "Sl"),
    explicit_expect_error = true,
  })

  -- Use protected call directly rather than with_error_capture
  -- This gives us more control over the error handling process
  local success, result = pcall(fn)

  -- Clear test metadata
  get_error_handler().set_current_test_metadata(nil)

  if success then
    print("Location of test: " .. test_location)
    print("Result value: " .. inspect(result))
    error(get_error_handler().test_expected_error("Function was expected to throw an error but it returned a value", {
      returned_value = result,
      source_file = caller_info.source,
      source_line = caller_info.currentline,
      "test_context = true",
    }))
  end

  -- Function threw an error as expected
  local err

  -- Normalize the error to a proper error object
  if type(result) == "table" and result.category and result.message then
    -- Already a proper error object
    err = result

    -- Ensure it has TEST_EXPECTED category
    if err.category ~= get_error_handler().CATEGORY.TEST_EXPECTED then
      err = get_error_handler().test_expected_error(
        err.message,
        {
          original_category = err.category,
          original_severity = err.severity,
          original_context = err.context,
          source_file = caller_info.source,
          source_line = caller_info.currentline,
          validation_type = err.context and err.context.action,
        },
        err -- Preserve original error as cause
      )
    end
  elseif type(result) == "string" then
    -- String error
    err = get_error_handler().test_expected_error(result, {
      source_file = caller_info.source,
      source_line = caller_info.currentline,
      raw_error = result,
    })
  else
    -- Other type of error
    err = get_error_handler().test_expected_error(
      "Error of type " .. type(result) .. ": " .. tostring(result),
      {
        source_file = caller_info.source,
        source_line = caller_info.currentline,
        error_type = type(result),
        error_value = tostring(result),
      },
      result -- Include original value as cause if possible
    )
  end

  -- Check if the error message matches the expected pattern
  if message_pattern and err.message and not err.message:match(message_pattern) then
    error(get_error_handler().test_expected_error("Error message does not match expected pattern", {
      expected_pattern = message_pattern,
      actual_message = err.message,
      source_file = caller_info.source,
      source_line = caller,
    }))
  end

  return err
end

---@class TestDirectory
---@field path string Path to the test directory
---@field create_file fun(file_path: string, content: string): string Creates a file in the test directory
---@field read_file fun(file_path: string): string|nil, string? Reads a file from the test directory
---@field create_subdirectory fun(subdir_path: string): string Creates a subdirectory
---@field file_exists fun(file_name: string): boolean Checks if a file exists in the test directory
---@field unique_filename fun(prefix?: string, extension?: string): string Generates a unique filename in the test directory
---@field create_numbered_files fun(basename: string, content_pattern: string, count: number): string[] Creates multiple numbered files
---@field write_file fun(filename: string, content: string): boolean, string? Writes a file and registers it for cleanup
---@field path_for fun(file_name: string): string|nil Retrieves the full path for a file created via this object by its relative name.

--- Creates a temporary directory using `temp_file.create_temp_directory` and returns an object
--- with helper methods for interacting with that directory (creating files/subdirs, checking existence, etc.).
--- The created directory is automatically registered for cleanup.
---@return TestDirectory test_directory An object representing the temporary directory.
---@throws table If directory creation via `temp_file` fails.
function helper.create_temp_test_directory()
  -- Create a temporary directory
  local dir_path, err = temp_file.create_temp_directory()
  if not dir_path then
    error(get_error_handler().io_error("Failed to create temporary test directory: " .. tostring(err), { error = err }))
  end

  -- Return a directory context with helper functions
  return {
    -- Full path to the temporary directory
    path = function()
      return dir_path
    end,

    -- Internal mapping of relative names to full paths
    _created_files = {},

    ---@param file_name string Relative path of the file to create
    ---@param content string Content to write to the file
    ---@return string file_path Full path to the created file
    create_file = function(self, file_name, content) -- Restored self
      local original_file_name = file_name -- Preserve original args
      local original_content = content
      local file_path = dir_path .. "/" .. original_file_name -- Define path using original name
      -- Removed original_file_path variable

      -- Ensure parent directories exist
      local dir_name = file_path:match("(.+)/[^/]+$")
      if dir_name and dir_name ~= dir_path then
        local success, mkdir_err = get_fs().create_directory(dir_name)
        if not success then
          error(get_error_handler().io_error("Failed to create parent directory: " .. dir_name, { error = mkdir_err }))
        end
        -- Register the created directory
        temp_file.register_directory(dir_name)
      end

      -- Write the file
      -- Write the file
      -- get_logger().info("Values PRE-fs.write_file", { path=file_path, content=original_content, type=type(original_content) }) -- REMOVED THIS LINE
      get_logger().trace("Attempting write_file in test_helper", { file_path_value = file_path })
      local success, write_err = get_fs().write_file(file_path, original_content) -- Use correct file_path and original_content
      if not success then
        get_logger().trace("write_file failed, logging path before error creation", { file_path_value = file_path })
        -- Use correct file_path in error message
        error(get_error_handler().io_error("Failed to create test file: " .. file_path, { error = write_err }))
      end

      -- Register the file with temp_file tracking system
      get_logger().trace("Registering temp file in test_helper", { file_path = file_path })
      temp_file.register_file(file_path)
      self._created_files[file_name] = file_path -- Store the mapping

      return file_path
    end,

    ---@param subdir_name string Relative path of the subdirectory to create
    ---@return string subdir_path Full path to the created subdirectory
    -- Helper to create a subdirectory
    create_subdirectory = function(self, subdir_name) -- Restored self
      local subdir_path = dir_path .. "/" .. subdir_name
      local success, err = get_fs().create_directory(subdir_path)
      if not success then
        error(get_error_handler().io_error("Failed to create test subdirectory: " .. subdir_path, { error = err }))
      end

      -- Register the directory with temp_file tracking system
      temp_file.register_directory(subdir_path)

      return subdir_path
    end,

    ---@param file_name string Name of the file relative to the test directory
    ---@return boolean exists Whether the file exists
    -- Helper to check if a file exists in this directory
    file_exists = function(self, file_name) -- Restored self
      return get_fs().file_exists(dir_path .. "/" .. file_name)
    end,

    ---@param file_name string Name of the file relative to the test directory
    ---@return string|nil content Content of the file, or nil if file couldn't be read
    ---@return string? error Error message if reading failed
    -- Helper to read a file from this directory
    read_file = function(self, file_name) -- Restored self
      return get_fs().read_file(dir_path .. "/" .. file_name)
    end,

    ---@param prefix? string Prefix for the filename (default: "temp")
    ---@param extension? string File extension without dot (default: "tmp")
    ---@return string filename A unique filename (not a full path)
    -- Helper to generate a unique filename in the test directory
    unique_filename = function(self, prefix, extension) -- Restored self
      prefix = prefix or "temp"
      extension = extension or "tmp"

      local timestamp = os.time()
      local random = math.random(10000, 99999)
      return prefix .. "_" .. timestamp .. "_" .. random .. "." .. extension
    end,

    ---@param basename string Base name for the numbered files
    ---@param content_pattern string Pattern to format the content, should include a %d placeholder
    ---@param count number Number of files to create
    ---@return string[] List of created file paths
    -- Helper to create a series of numbered files
    create_numbered_files = function(self, basename, content_pattern, count) -- Restored self
      local files = {}
      for i = 1, count do
        local filename = string.format("%s_%03d.txt", basename, i)
        local content = string.format(content_pattern, i)
        local path = dir_path .. "/" .. filename
        local success, err = get_fs().write_file(path, content)
        if not success then
          error(get_error_handler().io_error("Failed to create numbered test file: " .. path, { error = err }))
        end
        temp_file.register_file(path)
        self._created_files[filename] = path -- Store the mapping
        table.insert(files, path)
      end
      return files
    end,

    ---@param filename string Name of the file relative to the test directory
    ---@param content string Content to write to the file
    ---@return boolean success Whether the file was successfully written
    ---@return string? error Error message if writing failed
    -- Helper to write a file that automatically registers it
    write_file = function(self, filename, content) -- Restored self
      local file_path = dir_path .. "/" .. filename
      local success, err = get_fs().write_file(file_path, content)
      if success then
        temp_file.register_file(file_path)
        self._created_files[filename] = file_path -- Store the mapping
      end
      return success, err
    end,

    ---@param file_name string The relative name of the file previously created.
    ---@return string|nil path The absolute path to the file, or nil if not found.
    -- Retrieves the absolute path for a file created via this object's methods.
    path_for = function(self, file_name) -- Restored self
      return self._created_files[file_name]
    end,
  }
end

--- Creates a temporary directory, populates it with files defined in `files_map`,
--- executes the `callback` function, and ensures the directory is cleaned up afterwards.
---@param files_map table<string, string> A map where keys are relative file paths within the temp directory and values are the file content.
---@param callback fun(dir_path: string, files: string[], test_dir: TestDirectory): any The function to execute after the directory and files are created. Receives the absolute path, list of created files, and the `TestDirectory` helper object.
---@return any result The results returned by the `callback` function.
---@throws table If directory/file creation fails, or if the `callback` function throws an error (the error is re-thrown after cleanup attempt).
function helper.with_temp_test_directory(files_map, callback)
  -- Create a temporary directory
  local test_dir = helper.create_temp_test_directory()

  -- Create all the specified files
  local created_files = {}
  get_logger().debug("Iterating files_map in with_temp_test_directory", { files_map_content = files_map }) -- Reverted to debug
  for file_name, content in pairs(files_map) do
    get_logger().debug(
      "Processing entry from files_map",
      { key_file_name = file_name, value_content = content, type_key = type(file_name), type_value = type(content) }
    ) -- Reverted to debug
    local file_path = test_dir:create_file(file_name, content) -- Use colon notation for method call
    table.insert(created_files, file_path)
  end

  -- Call the callback with the directory path and context
  local results = { pcall(callback, test_dir:path(), created_files, test_dir) }
  local success = table.remove(results, 1)

  -- Note: cleanup happens automatically via temp_file.cleanup_test_context
  -- which is called by the test runner

  if not success then
    error(results[1]) -- Re-throw the error
  end

  return unpack_table(results)
end

--- Manually registers an existing file path for automatic cleanup by the `temp_file` module.
---@param file_path string The absolute or relative path to the file.
---@return boolean success Always returns `true` (based on `temp_file.register_file`'s current return).
function helper.register_temp_file(file_path)
  return temp_file.register_file(file_path)
end

--- Manually registers an existing directory path for automatic cleanup by the `temp_file` module.
---@param dir_path string The absolute or relative path to the directory.
---@return boolean success Always returns `true` (based on `temp_file.register_directory`'s current return).
function helper.register_temp_directory(dir_path)
  return temp_file.register_directory(dir_path)
end

--- Executes a string of Lua code using `load()`.
---@param code string The Lua code string to execute.
---@return any|nil result The result(s) returned by the executed code, or `nil` on error.
---@return string? error_message Error message if loading or executing the code failed.
helper.execute_string = function(code)
  local fn, err = load(code)
  if not fn then
    return nil, err
  end
  return fn()
end

--- Asserts that an asynchronous function throws an error within a specified timeout.
--- It leverages `lib.async.parallel_async` to manage the execution and timeout.
--- If the function completes successfully, times out before throwing, or throws an error
--- whose message does not match the optional pattern, this helper will throw a test assertion failure.
---
---@param async_fn function The asynchronous function (must be usable with `async.async`) expected to throw.
---@param timeout_ms number The maximum time in milliseconds to wait for the error to occur.
---@param message_pattern? string Optional Lua pattern to match against the error message.
---@return table error The captured and validated error object (normalized to `TEST_EXPECTED` category).
---@throws table If the `async_fn` succeeds, if it times out before throwing an error, if the async module is unavailable, or if `message_pattern` is provided and the error message does not match.
---
---@usage
--- it_async("handles async failure within timeout", function()
---   local failing_op = async.async(function()
---     async.await(50)
---     error("Operation failed as expected")
---   end)
---
---   -- Assert that the operation fails within 100ms with a specific message
---   local err = test_helper.expect_async_error(failing_op, 100, "Operation failed")
---   expect(err).to.exist()
---   expect(err.message).to.match("Operation failed")
--- end)
function helper.expect_async_error(async_fn, timeout_ms, message_pattern, options)
  options = options or {}
  -- Validate arguments
  if type(async_fn) ~= "function" then
    error(get_error_handler().validation_error("First argument to expect_async_error must be a function"))
  end
  if type(timeout_ms) ~= "number" or timeout_ms <= 0 then
    error(get_error_handler().validation_error("Second argument (timeout_ms) must be a positive number"))
  end
  if message_pattern ~= nil and type(message_pattern) ~= "string" then
    error(get_error_handler().validation_error("Third argument (message_pattern) must be a string if provided"))
  end

  -- Get required modules
  local async_module = get_async()
  if not async_module then
    error(get_error_handler().internal_error("Async module (lib.async) is required for expect_async_error"))
  end
  local error_handler = get_error_handler() -- Already loaded via helper functions

  -- Set up test expectation context
  local caller_info = debug.getinfo(2, "Sl")
  local test_name = get_test_name()
  local test_location = get_test_location()
  error_handler.set_current_test_metadata({
    name = test_name,
    expect_error = true,
    caller_info = caller_info,
    function_info = debug.getinfo(async_fn, "Sl"),
    explicit_expect_error = true,
    async_expected_error = true, -- Custom flag
  })

  -- Use the async function directly (it's already an async function)
  local executor = async_fn -- async_fn is already an async function

  -- Run using parallel_async for timeout handling and execute the function
  local success, err_raw = pcall(async_module.parallel_async, { executor() }, timeout_ms)

  -- Always clear the test metadata after the call completes
  error_handler.set_current_test_metadata(nil)

  if success then
    -- Function completed without error, but an error was expected
    error("Async function was expected to throw an error but it completed successfully")
  end

  -- parallel_async threw an error, check if it was a timeout or the expected error
  local err_string = tostring(err_raw)
  if err_string:match("Timeout of %d+ms exceeded") or err_string:match("timeout") then -- Check for timeout indicators
    error(
      error_handler.test_expected_error(
        "Async function timed out after " .. timeout_ms .. "ms while expecting an error",
        {
          source_file = caller_info.source,
          source_line = caller_info.currentline,
          timeout_ms = timeout_ms,
          original_error = err_raw,
          test_context = true,
        }
      )
    )
  end

  -- It wasn't a timeout, so process the captured error (similar to expect_error)
  local err_norm
  if type(err_raw) == "table" and err_raw.category and err_raw.message then
    -- Already a proper error object - normalize category
    err_norm = err_raw
    if err_norm.category ~= error_handler.CATEGORY.TEST_EXPECTED then
      err_norm = error_handler.test_expected_error(
        err_norm.message,
        {
          original_category = err_norm.category,
          original_severity = err_norm.severity,
          original_context = err_norm.context,
          source_file = caller_info.source,
          source_line = caller_info.currentline,
          validation_type = err_norm.context and err_norm.context.action,
        },
        err_norm -- Preserve original as cause
      )
    end
  elseif type(err_raw) == "string" then
    err_norm = error_handler.test_expected_error(err_raw, {
      source_file = caller_info.source,
      source_line = caller_info.currentline,
      raw_error = err_raw,
    })
  else
    err_norm = error_handler.test_expected_error(
      "Error of type " .. type(err_raw) .. ": " .. tostring(err_raw),
      {
        source_file = caller_info.source,
        source_line = caller_info.currentline,
        error_type = type(err_raw),
        error_value = tostring(err_raw),
      },
      err_raw -- Include original value as cause if possible
    )
  end

  -- Check if the error message matches the expected pattern
  -- Removed diagnostic log
  if message_pattern and err_norm.message and not err_norm.message:match(message_pattern) then
    error(error_handler.test_expected_error("Async error message does not match expected pattern", {
      expected_pattern = message_pattern,
      actual_message = err_norm.message,
      source_file = caller_info.source,
      source_line = caller_info.currentline, -- Corrected source line reference
      test_context = true,
    }))
  end

  return err_norm
end

--- Runs a function with a specific module freshly required, after executing a setup function.
--- Ensures the module is re-required for the scope of the run_fn call and then restored.
--- This is useful for testing modules that cache their dependencies upon initial require,
--- allowing mocks to be injected for a specific test run.
---
---@param module_name_to_isolate string The fully qualified name of the module to isolate and re-require.
---@param setup_fn function|nil A function to run *after* the module is marked for re-requiring but *before* it's actually re-required.
---                         This function should set up any mocks in `package.loaded` for dependencies of the isolated module.
---@param run_fn function The function to execute, which will receive the freshly required isolated_module as its first argument.
---@param ... any Additional arguments to pass to run_fn after the isolated_module.
---@return boolean success True if setup_fn, require, and run_fn all completed without error; false otherwise.
---@return any ... If success is true, returns the results of run_fn. If success is false, returns a single error_object.
function helper.with_isolated_module_run(module_name_to_isolate, setup_fn, run_fn, ...)
  local eh = get_error_handler() -- Get the error handler instance
  if not eh then
    error("Critical: error_handler module not available in test_helper.with_isolated_module_run", 0)
  end

  local original_package_loaded_entry = package.loaded[module_name_to_isolate]
  package.loaded[module_name_to_isolate] = nil -- Force re-require

  if setup_fn then
    local setup_ok, setup_err_val = pcall(setup_fn)
    if not setup_ok then
      package.loaded[module_name_to_isolate] = original_package_loaded_entry -- Restore
      local err_obj =
        eh.new("SETUP_ERROR", "Error during setup_fn for with_isolated_module_run: " .. tostring(setup_err_val), {
          module_name = module_name_to_isolate,
          original_error = setup_err_val,
        })
      return false, err_obj
    end
  end

  local require_ok, isolated_module_or_err = pcall(require, module_name_to_isolate)
  if not require_ok then
    package.loaded[module_name_to_isolate] = original_package_loaded_entry -- Restore
    local err_obj = eh.new(
      "REQUIRE_ERROR",
      "Failed to re-require isolated module '" .. module_name_to_isolate .. "': " .. tostring(isolated_module_or_err),
      {
        module_name = module_name_to_isolate,
        original_error = isolated_module_or_err,
      }
    )
    return false, err_obj
  end
  -- If require_ok is true, isolated_module_or_err is the actual module

  local pcall_results = { pcall(run_fn, isolated_module_or_err, ...) } -- Pass the loaded module
  local run_fn_success = table.remove(pcall_results, 1)

  package.loaded[module_name_to_isolate] = original_package_loaded_entry -- Always restore

  if not run_fn_success then
    local run_fn_err_val = pcall_results[1]
    local err_obj = eh.new(
      "RUN_FN_ERROR",
      "Error during isolated run_fn for module '" .. module_name_to_isolate .. "': " .. tostring(run_fn_err_val),
      {
        module_name = module_name_to_isolate,
        original_error = run_fn_err_val,
      }
    )
    return false, err_obj
  end

  return true, unpack_table(pcall_results)
end

return helper
