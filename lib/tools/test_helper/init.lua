---@class TestHelper The public API for the test helper module.
---@field with_error_capture fun(func: function): function Wraps a function to safely capture errors. The wrapper function returns `result, nil` on success, `nil, error_object` on failure. @throws table Re-throws unexpected errors from `pcall` if error handler integration fails.
---@field expect_error fun(func: function, message_pattern?: string): table Throws an assertion error if `func` does not throw an error, or if the error message doesn't match `message_pattern`. Returns the captured error object if requirements met. @throws table If the function `fn` does not throw, or if the error message does not match `message_pattern`.
---@field create_temp_test_directory fun(): TestDirectory Creates a temporary test directory with helper methods. @throws table If directory creation fails.
---@field with_temp_test_directory fun(files_map: table<string, string>, callback: fun(dir_path: string, files: string[], test_dir: TestDirectory): any): any Creates a directory with predefined files, runs `callback`, and ensures cleanup. Returns callback results. @throws table If directory/file creation fails or if `callback` throws.
---@field register_temp_file fun(file_path: string): boolean Registers a file for automatic cleanup via `temp_file`.
---@field register_temp_directory fun(dir_path: string): boolean Registers a directory for automatic cleanup via `temp_file`.
---@field execute_string fun(code: string): any|nil, string? Executes a string of Lua code using `load()`. Returns results or `nil, error_message`.
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
---    test_dir.create_file("config.json", '{"setting": "value"}')
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

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler, _fs

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

local temp_file = try_require("lib.tools.filesystem.temp_file")

local helper = {}

-- Compatibility function for table unpacking
local unpack_table = table.unpack or unpack

--- Wraps a function to safely capture any errors it throws.
--- Sets the error handler's test context to expect errors, runs the function via `pcall`,
--- processes the captured error into a standardized `TEST_EXPECTED` error object,
--- and clears the test context.
---@param fn function The function to wrap.
---@return function wrapper A new function that, when called, executes `fn` and returns `result, nil` on success or `nil, error_object` on failure.
---@throws table Re-throws errors from `pcall` if error processing itself fails critically.
function helper.with_error_capture(fn)
  return function()
    -- Set up test to expect errors
    get_error_handler().set_current_test_metadata({
      name = debug.getinfo(2, "n").name or "unknown",
      expect_error = true,
      caller_info = debug.getinfo(2, "Sl"),
      function_info = debug.getinfo(fn, "Sl"),
    })

    -- Use protected call
    local success, results = pcall(fn)

    -- Clear test metadata
    get_error_handler().set_current_test_metadata(nil)

    -- Handle functions that return (nil, error_object) successfully
    if
      success
      and #results >= 1
      and results[1] == nil
      and #results >= 2
      and type(results[2]) == "table"
      and get_error_handler().is_error(results[2])
    then
      -- Treat this as a captured error
      local captured_err = results[2]
      -- Process it similarly to the 'if not success' block
      -- For simplicity, just wrap it as TEST_EXPECTED
      local error_context = {
        source = debug.getinfo(2, "S").source,
        error_capture_location = debug.getinfo(2, "S").source .. ":" .. debug.getinfo(2, "l").currentline,
        in_test_context = true,
        returned_error = true, -- Indicate it was returned, not thrown
      }
      return nil,
        get_error_handler().test_expected_error(
          captured_err.message,
          error_context,
          captured_err -- Preserve original error as cause
        )
    end

    if not success then
      -- Captured an expected error (thrown) - process it
      local thrown_err = results[1] -- Get the actual error value

      -- Create base context with source information
      local error_context = {
        source = debug.getinfo(2, "S").source,
        error_capture_location = debug.getinfo(2, "S").source .. ":" .. debug.getinfo(2, "l").currentline,
        in_test_context = true,
      }

      -- Enhanced error processing with more specific cases:

      -- 1. Already a properly formatted error object
      if type(thrown_err) == "table" and thrown_err.category and thrown_err.message then
        -- 1a. Already has TEST_EXPECTED category - just return it
        if thrown_err.category == get_error_handler().CATEGORY.TEST_EXPECTED then
          return nil, thrown_err
        end

        -- 1b. Is a VALIDATION error from expect().to.exist() or similar
        if thrown_err.category == get_error_handler().CATEGORY.VALIDATION then
          -- Validation errors in test context should be treated as TEST_EXPECTED
          return nil,
            get_error_handler().test_expected_error( -- Use get_error_handler()
              thrown_err.message,
              {
                original_category = thrown_err.category,
                original_severity = thrown_err.severity,
                original_context = thrown_err.context,
                assertion_type = result.context and result.context.action,
                test_error = true,
                test_error = true,
              },
              thrown_err -- Preserve original error as cause
            )
        end

        -- 1c. Has a nested cause that might be TEST_EXPECTED
        if type(thrown_err.cause) == "table" and thrown_err.cause.category == get_error_handler().CATEGORY.TEST_EXPECTED then -- Use get_error_handler()
          return nil,
            get_error_handler().test_expected_error(
              thrown_err.message,
              {
                original_category = thrown_err.category,
                original_severity = thrown_err.severity,
                original_context = thrown_err.context,
                from_cause = true,
              },
              thrown_err.cause -- Use the original TEST_EXPECTED cause
            )
        end

        -- 1d. Has a context with an error that is TEST_EXPECTED
        if
          type(thrown_err.context) == "table"
          and type(thrown_err.context.error) == "table"
          and thrown_err.context.error.category == get_error_handler().CATEGORY.TEST_EXPECTED -- Use get_error_handler()
        then
          return nil,
            get_error_handler().test_expected_error(
              thrown_err.message,
              {
                original_category = thrown_err.category,
                original_severity = thrown_err.severity,
                original_context = thrown_err.context,
              },
              thrown_err.context.error -- Use the original TEST_EXPECTED error from context
            )
        end

        -- 1e. Is an assertion error indicated by specific context properties
        if
          type(thrown_err.context) == "table"
          and (
            thrown_err.context.action
            or thrown_err.context.assertion
            or (thrown_err.context.negate ~= nil)
            or thrown_err.context.expected
          )
        then
          -- This is likely an assertion error
          return nil,
            get_error_handler().test_expected_error( -- Use get_error_handler()
              thrown_err.message,
              {
                original_category = thrown_err.category,
                original_severity = thrown_err.severity,
                original_context = thrown_err.context,
                result, -- Preserve original error as cause
              },
              thrown_err -- Preserve original error as cause
            )
        end

        -- 1f. Any other structured error - wrap it in TEST_EXPECTED
        return nil,
          get_error_handler().test_expected_error( -- Use get_error_handler()
            thrown_err.message,
            {
              original_category = thrown_err.category,
              original_severity = thrown_err.severity,
              original_context = thrown_err.context,
            },
            thrown_err -- Preserve original error as cause
          )
      end

      -- 2. String error (most common case)
      if type(thrown_err) == "string" then
        -- 2a. If the string has specific patterns indicating assertion errors
        if
          thrown_err:match("VALIDATION")
          or thrown_err:match("expected")
          or thrown_err:match("assertion")
          or thrown_err:match("to%.")
        then
          -- This is likely an assertion error reported as string
          error_context.assertion_error = true
          error_context.captured_error = thrown_err
          return nil, get_error_handler().test_expected_error(thrown_err, error_context) -- Use get_error_handler()
        end

        -- 2b. Regular string error
        error_context.captured_error = thrown_err
        return nil, get_error_handler().test_expected_error(thrown_err, error_context) -- Use get_error_handler()
      end

      -- 3. Any other type of error (fallback)
      error_context.error_type = type(thrown_err)
      error_context.error_value = tostring(thrown_err)

      return nil,
        get_error_handler().test_expected_error( -- Use get_error_handler()
          "Error of type " .. type(thrown_err) .. ": " .. tostring(thrown_err),
          error_context,
          thrown_err -- Include original value as cause if possible
        )
    end

    -- Return original results if successful and no error object was returned
    return unpack_table(results)
  end
end

--- Asserts that a function throws an error, optionally matching a pattern.
--- Sets the error handler context to expect an error, runs the function via `pcall`,
--- and throws a test assertion error if the function *doesn't* throw or if the message doesn't match.
---@param fn function The function expected to throw an error.
---@param message_pattern? string Optional Lua pattern to match against the error message.
---@return table error The captured error object if the function threw an error as expected and the message matched (if provided).
---@throws table If the function `fn` does not throw, or if `message_pattern` is provided and the error message does not match.
function helper.expect_error(fn, message_pattern)
  -- Set up test expectation context
  local caller_info = debug.getinfo(2, "Sl")
  get_error_handler().set_current_test_metadata({
    name = debug.getinfo(2, "n").name or "unknown",
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
    -- Function did not throw an error as expected
    error(get_error_handler().test_expected_error("Function was expected to throw an error but it returned a value", {
      returned_value = result,
      source_file = caller_info.source,
      source_line = caller_info.currentline,
      test_context = true,
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
    path = dir_path,

    ---@param file_name string Relative path of the file to create
    ---@param content string Content to write to the file
    ---@return string file_path Full path to the created file
    -- Helper to create a file in this directory
    create_file = function(file_name, content)
      local file_path = dir_path .. "/" .. file_name

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
      local success, write_err = get_fs().write_file(file_path, content)
      if not success then
        error(get_error_handler().io_error("Failed to create test file: " .. file_path, { error = write_err }))
      end

      -- Register the file with temp_file tracking system
      temp_file.register_file(file_path)

      return file_path
    end,

    ---@param subdir_name string Relative path of the subdirectory to create
    ---@return string subdir_path Full path to the created subdirectory
    -- Helper to create a subdirectory
    create_subdirectory = function(subdir_name)
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
    file_exists = function(file_name)
      return get_fs().file_exists(dir_path .. "/" .. file_name)
    end,

    ---@param file_name string Name of the file relative to the test directory
    ---@return string|nil content Content of the file, or nil if file couldn't be read
    ---@return string? error Error message if reading failed
    -- Helper to read a file from this directory
    read_file = function(file_name)
      return get_fs().read_file(dir_path .. "/" .. file_name)
    end,

    ---@param prefix? string Prefix for the filename (default: "temp")
    ---@param extension? string File extension without dot (default: "tmp")
    ---@return string filename A unique filename (not a full path)
    -- Helper to generate a unique filename in the test directory
    unique_filename = function(prefix, extension)
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
    create_numbered_files = function(basename, content_pattern, count)
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
        table.insert(files, path)
      end
      return files
    end,

    ---@param filename string Name of the file relative to the test directory
    ---@param content string Content to write to the file
    ---@return boolean success Whether the file was successfully written
    ---@return string? error Error message if writing failed
    -- Helper to write a file that automatically registers it
    write_file = function(filename, content)
      local file_path = dir_path .. "/" .. filename
      local success, err = get_fs().write_file(file_path, content)
      if success then
        temp_file.register_file(file_path)
      end
      return success, err
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
  for file_name, content in pairs(files_map) do
    local file_path = test_dir.create_file(file_name, content)
    table.insert(created_files, file_path)
  end

  -- Call the callback with the directory path and context
  local results = { pcall(callback, test_dir.path, created_files, test_dir) }
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

return helper
