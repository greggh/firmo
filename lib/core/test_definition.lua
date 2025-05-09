--- Firmo Test Definition Module
---
--- Provides the core BDD-style functions (`describe`, `it`, `before`, `after`, etc.)
--- for defining test structures, managing hooks, handling focus/skip states, filtering,
--- and collecting structured test results.
---
--- @module lib.core.test_definition
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 0.4.0

---@class TestDefinition The public API of the test definition module.
---@field describe fun(name: string, fn: function, options?: {focused?: boolean, excluded?: boolean, _parent_focused?: boolean}): nil Defines a test group (suite).
---@field fdescribe fun(name: string, fn: function): nil Defines a focused test group.
---@field xdescribe fun(name: string, fn: function): nil Defines a skipped test group.
---@field it fun(name: string, options_or_fn: table|function, fn?: function): nil Defines an individual test case. `options_or_fn` can be the test function or an options table `{focused?: boolean, excluded?: boolean, expect_error?: boolean, tags?: string[], timeout?: number}`.
---@field fit fun(name: string, options_or_fn: table|function, fn?: function): nil Defines a focused test case.
---@field xit fun(name: string, options_or_fn: table|function, fn?: function): nil Defines a skipped test case.
---@field before fun(fn: function): nil Registers a setup function to run before each test in the current block.
---@field after fun(fn: function): nil Registers a teardown function to run after each test in the current block.
---@field pending fun(message?: string): string Marks a test as pending by throwing a specific message.
---@field only_tags fun(...: string): TestDefinition Sets active tags for filtering tests. Returns self for chaining.
---@field tags fun(...: string): TestDefinition Applies tags to the current describe block. Returns self for chaining.
---@field filter_pattern fun(pattern: string): TestDefinition Sets a Lua pattern for filtering test names. Returns self for chaining.
---@field reset fun(): nil Resets the internal state (counters, hooks, results, focus, etc.).
---@field get_state fun(): {level: number, passes: number, errors: number, skipped: number, focus_mode: boolean, test_results: TestResult[]} Returns the current state.
---@field set_debug_mode fun(value: boolean): TestDefinition Enables/disables internal debug logging. Returns self for chaining.
---@field add_test_result fun(result: TestResult): TestResult|nil Adds a structured test result to the collection. Returns the added result or nil.
---@field STATUS TestStatus Enum containing test status constants (PASS, FAIL, SKIP, PENDING).
local M = {}

-- Forward declaration of module-level variables
local level = 0
local befores = {}
local afters = {}
local current_tags = {}
local active_tags = {}
local filter_pattern = nil
local focus_mode = false
local current_describe_block = nil

-- Define test status constants
---@class TestStatus Enum defining possible test statuses.
---@field PASS string Indicates a test passed successfully.
---@field FAIL string Indicates a test failed (an assertion failed or an unexpected error occurred).
---@field SKIP string Indicates a test was intentionally skipped (e.g., via `xit`, `xdescribe`, filtering).
---@field PENDING string Indicates a test is marked as pending (not yet implemented) via `pending()`.
local TEST_STATUS = {
  PASS = "pass",
  FAIL = "fail",
  SKIP = "skip",
  PENDING = "pending",
}

-- Track tests
local passes = 0
local errors = 0
local skipped = 0
local test_blocks = {}
local test_paths = {}
---@class TestResult Represents the outcome of a single test case execution.
---@field status string The final status of the test (`TestStatus.PASS`, `TestStatus.FAIL`, `TestStatus.SKIP`, `TestStatus.PENDING`).
---@field name string The name of the test case (from `it(...)`).
---@field path string[] An array representing the hierarchical path to the test (e.g., `{"Suite 1", "Sub-suite A", "Test Case X"}`).
---@field path_string string The full path to the test represented as a single string (e.g., `"Suite 1 / Sub-suite A / Test Case X"`).
---@field timestamp number The Unix timestamp (from `os.time()`) when the test result was recorded.
---@field execution_time? number The duration of the test execution in seconds (optional).
---@field options? table The options table passed to the `it` function (optional).
---@field error? any The raw error object or value captured if the test failed unexpectedly (optional).
---@field error_message? string A formatted string representation of the error (optional).
---@field expect_error? boolean `true` if the test was configured with `{expect_error = true}` (optional).
---@field reason? string An optional message explaining why a test was skipped or marked as pending (optional).

-- Collection of structured test result objects
local test_results = {}

-- Error handling and logging
-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler, _logging

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

local quality_module = try_require("lib.quality")

--- Get the success handler module with lazy loading to avoid circular dependencies
---@return table|nil The error handler module or nil if not available
local function get_error_handler()
  if not _error_handler then
    _error_handler = try_require("lib.tools.error_handler")
  end
  return _error_handler
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
    return logging.get_logger("test_definition")
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


local temp_file = try_require("lib.tools.filesystem.temp_file")

--- Merges a user-provided options table with a defaults table.
--- Creates a new table with defaults, then overwrites with values from `options`.
---@param options table|nil The user-provided options table. Can be nil.
---@param defaults table The table containing default values.
---@return table result The merged options table.
---@private
local function merge_options(options, defaults)
  options = options or {}
  local result = {}
  for k, v in pairs(defaults) do
    result[k] = options[k] ~= nil and options[k] or v
  end
  return result
end

--- Checks if a set of test tags contains at least one of the currently active filter tags.
--- If `active_tags` is empty, it always returns true.
---@param test_tags table Array of tags applied to the test/block being checked.
---@return boolean `true` if filtering is inactive OR if `test_tags` shares at least one tag with `active_tags`, `false` otherwise.
---@private
local function has_required_tags(test_tags)
  if not active_tags or #active_tags == 0 then
    return true -- No active tag filter, always passes
  end

  for _, tag in ipairs(active_tags) do
    for _, test_tag in ipairs(test_tags) do
      if test_tag == tag then
        return true
      end
    end
  end

  return false
end

-- Public interface

--- Set active tags for test filtering
--- This function specifies which tags must be present on a test for it to be run.
--- Tests without at least one of the specified tags will be skipped during execution.
--- This provides a way to selectively run subsets of tests, such as running only
--- "integration" or "performance" tests.
---
---@param ... string Tags to filter by
---@return TestDefinition The module instance (`M`) for method chaining.
---
---@usage
--- -- Only run tests tagged with "integration"
--- firmo.only_tags("integration")
---
--- -- Run tests tagged with either "fast" or "critical"
--- firmo.only_tags("fast", "critical")
function M.only_tags(...)
  active_tags = { ... }
  return M
end

--- Set tags for the current test block
--- This function applies tags to the current test block and all tests within it.
--- Tags can be used to categorize tests and later filter test execution.
--- Common tags might include "unit", "integration", "slow", or feature names.
---
---@param ... string Tags to apply
---@return TestDefinition The module instance (`M`) for method chaining.
---
---@usage
--- -- Tag a block of tests
--- describe("Database operations", function()
---   firmo.tags("integration", "database")
---
---   it("should connect to database", function()
---     -- This test will have both "integration" and "database" tags
---   end)
--- end)
function M.tags(...)
  local new_tags = { ... }
  current_tags = new_tags
  return M
end

--- Set a filter pattern for test names
--- This function specifies a Lua pattern that test names must match to be run.
--- Tests with names that don't match the pattern will be skipped.
--- This allows for focusing on specific types of tests without modifying the code.
---
---@param pattern string Pattern to filter test names
---@return TestDefinition The module instance (`M`) for method chaining.
---
---@usage
--- -- Only run tests with "parse" in their name
--- firmo.filter_pattern("parse")
---
--- -- Only run tests that start with "should"
--- firmo.filter_pattern("^should")
---
--- -- Run tests related to file operations
--- firmo.filter_pattern("file")
function M.filter_pattern(pattern)
  filter_pattern = pattern
  return M
end

--- Mark a test as pending
--- This function is used within test cases to indicate that the test is not yet
--- implemented or is temporarily disabled. Pending tests will be reported differently
--- than failures, making it clear they are intentionally incomplete.
---
---@param message? string Optional message explaining why the test is pending
---@return string The pending message
---
---@usage
--- -- Mark a test as pending without a message
--- it("should handle edge cases", function()
---   return firmo.pending()
--- end)
---
--- -- Mark a test as pending with an explanation
--- it("should optimize for large datasets", function()
---   return firmo.pending("Waiting for optimization strategy decision")
--- end)
function M.pending(message)
  message = message or "Test not yet implemented"
  return message
end

--- Create a test group
--- This function creates a block of related tests, providing hierarchical organization.
--- Describe blocks can be nested to create a tree-like structure of tests, with each
--- level having its own setup (before) and teardown (after) hooks. The callback
--- function contains test definitions and possibly nested describe blocks.
---
---@param name string Name of the test group
---@param fn function Function containing the test group
---@param options? {focused?: boolean, excluded?: boolean, _parent_focused?: boolean} Optional table containing flags:
---   - `focused`: If true, marks this group as focused.
---   - `excluded`: If true, marks this group to be skipped.
---   - `_parent_focused`: Internal flag indicating if a parent group was focused.
---@return nil
---@throws table If the test group function `fn` throws an error during execution. The error is caught, logged, and execution continues, but the error might be re-thrown depending on the error handler configuration.
---
---@usage
--- -- Basic describe block
--- describe("User authentication", function()
---   it("should allow valid users to log in", function()
---     -- test implementation
---   end)
---
---   it("should reject invalid credentials", function()
---     -- test implementation
---   end)
--- end)
---
--- -- Nested describe blocks
--- describe("File operations", function()
---   describe("Reading files", function()
---     it("should read text files", function() end)
---     it("should read binary files", function() end)
---   end)
---
---   describe("Writing files", function()
---     it("should write text files", function() end)
---     it("should write binary files", function() end)
---   end)
--- end)
function M.describe(name, fn, options)
  options = options or {}
  local parent_focused = options._parent_focused or false
  local focused = options.focused or false
  local excluded = options.excluded or false

  -- Update focus mode if this is a focused describe
  if focused and not excluded then
    focus_mode = true
  end

  -- Save previous tags and level
  local previous_level = level
  local previous_tags = {}
  for i, v in ipairs(current_tags) do
    previous_tags[i] = v
  end

  -- Create a new describe block
  local block = {
    name = name,
    parent = current_describe_block,
    focused = focused,
    excluded = excluded,
    parent_focused = parent_focused,
    tags = {},
  }

  -- Copy current tags to the block
  for i, v in ipairs(current_tags) do
    block.tags[i] = v
  end

  -- Check if block should be skipped based on tags
  local should_skip_block = not has_required_tags(block.tags)

  -- Save previous describe block and set current
  local previous_describe_block = current_describe_block
  current_describe_block = block

  -- Insert block into test_blocks
  table.insert(test_blocks, block)

  -- Increase level and ensure hooks tables exist
  level = level + 1
  befores[level] = befores[level] or {}
  afters[level] = afters[level] or {}

  -- Always execute the function 'fn' to discover nested tests, even if skipped.
  -- The 'it' function will handle skipping based on the 'excluded' flag on the block.
  local success, err = get_error_handler().try(fn)
  if not success then
    -- Handle errors during describe block definition
    get_logger().error("Error during describe block definition: " .. get_error_handler().format_error(err), {
      block_name = name,
      level = level,
    })
    errors = errors + 1
    -- Record this suite itself as failing due to definition error? Might be complex.
    -- For now, just log the error. The runner should still report failures.
  end

  -- Restore previous state
  level = previous_level
  current_tags = previous_tags
  current_describe_block = previous_describe_block
end

--- Create a focused test group
--- This function creates a test group that will be executed exclusively, along with
--- any other focused tests. All non-focused tests will be skipped when focus mode
--- is active. This is useful for temporarily focusing on a specific area of the
--- test suite during development or debugging.
---
---@param name string Name of the test group
---@param fn function Function containing the test group
---@return nil
---
---@usage
--- -- Only this test group and its tests will run
--- fdescribe("Authentication module", function()
---   it("should authenticate valid users", function()
---     -- Test implementation
---   end)
---
---   it("should reject invalid credentials", function()
---     -- Test implementation
---   end)
--- end)
---
--- -- These tests will be skipped when focus mode is active
--- describe("Other module", function()
---   it("will be skipped when focus mode is active", function() end)
--- end)
function M.fdescribe(name, fn)
  return M.describe(name, fn, { focused = true })
end

--- Create a skipped test group
--- This function creates a test group that will be skipped during execution.
--- This is useful for temporarily disabling a group of tests that might be
--- broken, incomplete, or not relevant to the current development focus.
---
---@param name string Name of the test group
---@param fn function Function containing the test group
---@return nil
---
---@usage
--- -- This entire group of tests will be skipped
--- xdescribe("Work in progress module", function()
---   it("has tests that aren't ready yet", function()
---     -- Incomplete test
---   end)
---
---   it("contains features under development", function()
---     -- Incomplete test
---   end)
--- end)
---
--- -- Normal tests continue to run
--- describe("Stable module", function()
---   it("runs normally", function() end)
--- end)
function M.xdescribe(name, fn)
  return M.describe(name, fn, { excluded = true })
end

--- Create a test case
--- This function defines an individual test case within a describe block.
--- Each test contains assertions that verify specific behaviors of the code
--- being tested. Tests can have options for controlling execution,
--- such as focusing, skipping, or expecting errors.
--- If the `lib.quality` module is loaded and its `config.enabled` is true, this function will also call `quality_module.start_test()` before the test logic executes and `quality_module.end_test()` after the test logic completes (regardless of success or failure of the test itself).
---
---@param name string Name/description of the test case.
---@param options_or_fn table|function Either the test function itself, or an options table `{focused?: boolean, excluded?: boolean, expect_error?: boolean, tags?: string[], timeout?: number}`.
---@param fn? function The test function, if `options_or_fn` was an options table.
---@return nil
---@throws table If the test function `fn` throws an unexpected error (i.e., `expect_error` was not `true`). The error is caught, logged as a failure, and execution continues.
---
---@usage
--- -- Basic test case
--- it("should add two numbers correctly", function()
---   expect(1 + 2).to.equal(3)
--- end)
---
--- -- Test with options
--- it("should throw an error for invalid input", {
---   expect_error = true,
---   tags = {"validation", "error-handling"}
--- }, function()
---   local result = validate_input(nil)
---   -- This test passes if an error is thrown
--- end)
---
--- -- Test with timeout
--- it("should complete within time limit", {
---   timeout = 1000 -- milliseconds
--- }, function()
---   perform_operation()
---   expect(operation_completed).to.be_truthy()
--- end)
function M.it(name, options_or_fn, fn)
  -- Determine arguments based on signature
  local options = {}
  local test_fn -- Use a different name for the function variable

  if type(options_or_fn) == "function" then
    -- Signature: it(desc, func)
    options = {}
    test_fn = options_or_fn
  elseif type(options_or_fn) == "table" then
    -- Signature: it(desc, options, func_arg)
    options = options_or_fn
    test_fn = fn -- Use the third argument parameter named 'fn'
    if type(test_fn) ~= "function" then
      error("Invalid arguments to it(): Expected function as third argument when second is options table.", 2)
    end
  else -- options_or_fn is nil or some other type
    -- Signature: it(desc, nil, func_arg)
    options = {}
    test_fn = fn -- Use the third argument parameter named 'fn'
    if type(test_fn) ~= "function" then
      error("Invalid arguments to it(): Expected function as second or third argument.", 2)
    end
  end

  -- Apply defaults to options
  options = merge_options(options, {
    focused = false,
    excluded = false,
    expect_error = false,
    tags = {},
    timeout = nil,
  })

  -- Always clear any existing metadata before setting new metadata
  get_error_handler().set_current_test_metadata(nil)

  -- Set error handler metadata for the test
  get_error_handler().set_current_test_metadata({
    expect_error = options.expect_error,
    name = name,
  })

  -- Determine if test should be skipped based on focus mode
  local should_skip = false

  -- Skip if parent describe block was excluded
  if current_describe_block and current_describe_block.excluded then
    should_skip = true
  end

  -- Skip if exclude flag is set directly on the test
  if options.excluded then
    should_skip = true
  end

  -- Skip if there are focused tests and this one isn't focused
  if focus_mode and not options.focused and not (current_describe_block and current_describe_block.focused) then
    should_skip = true
  end

  -- Skip if tags don't match
  local test_tags = {}
  -- Add tags from current describe block
  if current_describe_block and current_describe_block.tags then
    for _, tag in ipairs(current_describe_block.tags) do
      table.insert(test_tags, tag)
    end
  end

  -- Add tags from options
  for _, tag in ipairs(options.tags) do
    table.insert(test_tags, tag)
  end

  -- Add tags from current context
  for _, tag in ipairs(current_tags) do
    table.insert(test_tags, tag)
  end

  -- Skip if test doesn't have required tags
  if not has_required_tags(test_tags) then
    should_skip = true
  end

  -- Skip if name doesn't match pattern
  if filter_pattern and name:match(filter_pattern) == nil then
    should_skip = true
  end

  -- Record test path
  local path = {}
  local current = current_describe_block
  while current do
    table.insert(path, 1, current.name)
    current = current.parent
  end
  table.insert(path, name)

  -- Store full test path
  table.insert(test_paths, path)

  if should_skip then
    -- Record this test as skipped with structured data
    local result = M.add_test_result({
      status = TEST_STATUS.SKIP,
      name = name,
      path = path,
      path_string = table.concat(path, " / "),
      timestamp = os.time(),
      options = options,
      reason = "Test skipped due to filtering or tagging",
    })

    -- Log as skipped with proper structure
    get_logger().info("Test skipped: " .. name, {
      test_name = name,
      test_path = table.concat(path, " / "),
      test_result = result,
    })

    return
  end

  -- Run test with proper error handling
  local test_start_time = os.clock()

  -- Always ensure metadata is cleared after the test, regardless of outcome
  local cleanup = function()
    get_error_handler().set_current_test_metadata(nil)
  end

  -- Start quality analysis for this test if enabled
  if quality_module and quality_module.config and quality_module.config.enabled then
    -- Construct full_test_name similarly to how path_string is made for results
    -- This needs to match the name that quality.end_test() will expect based on quality.start_test().
    -- The 'path' variable is suitable here as it's already built for test results.
    local full_test_name_for_quality = table.concat(path, " / ")

    -- Calculate describe depth for quality context
    local describe_depth = 0
    local temp_block = current_describe_block -- current_describe_block is available in M.it
    while temp_block do
      describe_depth = describe_depth + 1
      temp_block = temp_block.parent
    end

    local quality_context = {
      has_describe = describe_depth > 0,
      has_it = true, -- We are in an 'it' block
      nesting_level = describe_depth + 1, -- +1 for the 'it' block itself
      -- has_before_after could also be passed if M.before/M.after set a flag in current_describe_block
    }
    get_logger().trace("Calling quality_module.start_test", { test_name = full_test_name_for_quality, context = quality_context })
    quality_module.start_test(full_test_name_for_quality, quality_context)
  end

  local success, err = get_error_handler().try(function()
    -- Set temporary file context
    temp_file.set_current_test_context({
      type = "test",
      name = name,
      path = table.concat(path, " / "),
    })

    -- Run before hooks for each level
    for i = 1, level do -- Correctly iterate through levels
      for _, hook in ipairs(befores[i] or {}) do -- Iterate hooks within the level loop
        hook()
      end
    end -- Correctly close the level loop

    -- Run the test
    assert(type(test_fn) == "function", "INTERNAL ERROR: test_fn is nil before pcall in test runner!") -- Add assertion
    test_fn() -- Use the correctly assigned test function variable

    -- Run after hooks in reverse order
    for i = level, 1, -1 do
      for _, hook in ipairs(afters[i] or {}) do
        hook()
      end
    end

    -- Clean up test context
    temp_file.set_current_test_context(nil)

    -- Run cleanup to clear metadata
    cleanup()

    -- Create a test pass result
    local result = M.add_test_result({
      status = TEST_STATUS.PASS,
      name = name,
      path = path,
      path_string = table.concat(path, " / "),
      execution_time = os.clock() - test_start_time,
      timestamp = os.time(),
      options = options,
    })

    -- Log pass with proper structure
    get_logger().info("Test passed: " .. name, {
      test_name = name,
      test_path = table.concat(path, " / "),
      test_result = result,
    })
  end)

  -- End quality analysis for this test if enabled
  -- This is called after the try block and before final cleanup/error handling for the 'it' block.
  if quality_module and quality_module.config and quality_module.config.enabled then
    -- quality_module.end_test() uses its internal 'current_test' which was set by start_test.
    get_logger().trace("Calling quality_module.end_test for", { test_name_ended = table.concat(path, " / ") })
    quality_module.end_test()
  end

  -- Run cleanup to clear metadata (this was the original cleanup call for the 'it' block)
  cleanup()

  -- Handle test errors
  if not success then
    local execution_time = os.clock() - test_start_time

    if options.expect_error then
      -- Test expects an error, so this is a pass
      local result = M.add_test_result({
        status = TEST_STATUS.PASS,
        name = name,
        path = path,
        path_string = table.concat(path, " / "),
        execution_time = execution_time,
        timestamp = os.time(),
        options = options,
        expect_error = true,
        error = err, -- Store the error for inspection
      })

      -- Log pass with proper structure for expected errors
      get_logger().info("Test passed with expected error: " .. name, {
        test_name = name,
        test_path = table.concat(path, " / "),
        test_result = result,
        expect_error = true,
      })
    else
      -- Unexpected error, test fails
      local result = M.add_test_result({
        status = TEST_STATUS.FAIL,
        name = name,
        path = path,
        path_string = table.concat(path, " / "),
        execution_time = execution_time,
        timestamp = os.time(),
        options = options,
        error = err,
        error_message = get_error_handler().format_error(err),
      })

      -- Log error details with the structured result
      get_logger().error("Test failed: " .. get_error_handler().format_error(err), {
        test_name = name,
        test_path = table.concat(path, " / "),
        test_result = result,
        error_message = get_error_handler().format_error(err),
      })
    end
  end
end

--- Create a focused test case
--- This function creates a test case that will run exclusively, along with any other
--- focused tests. When any test is focused, all non-focused tests are skipped.
--- This is useful for temporarily focusing on a specific test during development
--- or debugging without having to run the entire test suite.
---
---@param name string Name of the test case
---@param options_or_fn table|function Options table or test function
---@param fn? function The test function, if `options_or_fn` was an options table.
---@return nil
---
---@usage
--- -- Only this test will run (and any other focused tests)
--- fit("should properly handle the edge case", function()
---   -- Test implementation
---   expect(edge_case_function()).to.be_truthy()
--- end)
---
--- -- This test will be skipped when any test is focused
--- it("regular test that will be skipped", function() end)
---
--- -- You can also provide options
--- fit("focused test with options", {
---   timeout = 2000,
---   tags = {"important", "edge-case"}
--- }, function()
---   expect(complex_operation()).to.be_truthy()
--- end)
function M.fit(name, options_or_fn, fn)
  -- Set focus mode
  focus_mode = true

  -- Determine if first argument is options or function
  local options = {}
  if type(options_or_fn) == "table" then
    options = options_or_fn
    options.focused = true
  else
    fn = options_or_fn
    options = { focused = true }
  end

  return M.it(name, options, fn)
end

--- Create a skipped test case
--- This function creates a test case that will be skipped during execution.
--- This is useful for temporarily disabling specific tests that may be
--- broken, incomplete, or not relevant to the current development focus.
---
---@param name string Name of the test case
---@param options_or_fn table|function Options table or test function
---@param fn? function The test function, if `options_or_fn` was an options table.
---@return nil
---
---@usage
--- -- This test will be skipped
--- xit("incomplete feature", function()
---   -- Incomplete or broken test
---   expect(unfinished_feature()).to.work()
--- end)
---
--- -- You can still provide options for future reference
--- xit("test requiring additional setup", {
---   timeout = 5000,
---   tags = {"integration", "database"}
--- }, function()
---   -- Test that will be skipped
--- end)
---
--- -- Regular tests continue to run
--- it("working feature", function()
---   expect(1 + 1).to.equal(2)
--- end)
function M.xit(name, options_or_fn, fn)
  -- Determine if first argument is options or function
  local options = {}
  if type(options_or_fn) == "table" then
    options = options_or_fn
    options.excluded = true
  else
    fn = options_or_fn
    options = { excluded = true }
  end

  return M.it(name, options, fn)
end

--- Add a setup hook for the current block
--- This function registers a setup function that will be executed before each test
--- within the current describe block, including tests in nested describe blocks.
--- Setup hooks run in hierarchical order, with parent block hooks running before
--- child block hooks, providing a way to establish test prerequisites.
---
---@param fn function Hook function to execute before each test
---@return nil
---
---@usage
--- -- Basic setup hook
--- describe("Database operations", function()
---   before(function()
---     -- Setup code that runs before each test in this block
---     db.connect()
---     db.clear_test_data()
---   end)
---
---   it("should insert records", function()
---     -- db is already connected and cleared due to before hook
---     db.insert({id = 1, name = "Test"})
---     expect(db.count()).to.equal(1)
---   end)
--- end)
---
--- -- Nested hooks demonstration
--- describe("Parent suite", function()
---   before(function()
---     -- This runs first for all tests in this and nested blocks
---     setup_parent_resources()
---   end)
---
---   describe("Child suite", function()
---     before(function()
---       -- This runs after parent's before but before the test
---       setup_child_resources()
---     end)
---
---     it("test in child suite", function()
---       -- Both parent and child setup have run
---     end)
---   end)
--- end)
function M.before(fn)
  befores[level] = befores[level] or {}
  table.insert(befores[level], fn)
end

--- Add a teardown hook for the current block
--- This function registers a teardown function that will be executed after each test
--- within the current describe block, including tests in nested describe blocks.
--- Teardown hooks run in reverse hierarchical order, with child block hooks running before
--- parent block hooks, providing a way to clean up test resources.
---
---@param fn function Hook function to execute after each test
---@return nil
---
---@usage
--- -- Basic temporary file usage with automatic cleanup
--- describe("File operations", function()
---   local temp_file = require("lib.tools.filesystem.temp_file")
---
---   it("should write to file with automatic cleanup", function()
---     temp_file.with_temp_file("initial content", function(file_path)
---       -- File is automatically created with content and cleaned up after this function
---       local content = read_file(file_path)
---       expect(content).to.equal("initial content")
---
---       -- Modify the file
---       write_to_file(file_path, "updated content")
---       expect(read_file(file_path)).to.equal("updated content")
---     end)
---     -- No manual cleanup needed - temp file is automatically removed
---   end)
--- end)
---
--- -- Error handling in teardown
--- after(function()
---   -- Always perform cleanup even if the test fails
---   local success, err = pcall(function()
---     if connection then connection:close() end
---     if temp_files then
---       for _, file in ipairs(temp_files) do
---         os.remove(file)
---       end
---     end
---   end)
---
---   if not success then
---     print("Warning: Cleanup failed - " .. tostring(err))
---   end
--- end)
function M.after(fn)
  afters[level] = afters[level] or {}
  table.insert(afters[level], fn)
end

--- Reset the test state
--- This function completely resets the internal state of the test system,
--- clearing all test definitions, hooks, results, and configuration.
--- It's typically called between test suite runs to ensure a clean slate
--- and prevent state from leaking between test executions.
---
---@return nil
---
---@usage
--- -- Reset before running a new test suite
--- require("my_test_suite")
---
--- -- Reset between individual test files
--- for _, file in ipairs(test_files) do
---   firmo.reset()
---   dofile(file)
--- end
---
--- -- Reset with custom configuration
--- firmo.reset()
--- firmo.only_tags("unit") -- Only run unit tests after reset
--- firmo.run()
function M.reset()
  level = 0
  befores = {}
  afters = {}
  current_tags = {}
  active_tags = {}
  filter_pattern = nil
  focus_mode = false
  current_describe_block = nil
  passes = 0
  errors = 0
  skipped = 0
  test_blocks = {}
  test_paths = {}
  test_results = {} -- Clear all test results
end

--- Get the current state of the test system
--- This function returns the current internal state of the test system, including
--- test counts, focus mode status, and test results. This is useful for generating
--- reports, monitoring test progress, and debugging test execution.
---
---@return {level: number, passes: number, errors: number, skipped: number, focus_mode: boolean, test_results: TestResult[]} state A table containing the current internal state.
---
---@usage
--- -- Get test statistics
--- local state = firmo.get_state()
--- print(string.format("Tests: %d passed, %d failed, %d skipped",
---   state.passes, state.errors, state.skipped))
---
--- -- Check if focus mode is active
--- if state.focus_mode then
---   print("Warning: Focus mode is active - some tests are being skipped")
--- end
---
--- -- Inspect test results
--- for _, result in ipairs(state.test_results) do
---   if result.status == "fail" then
---     print(string.format("FAILURE: %s - %s",
---       result.path_string, result.error_message or "unknown error"))
---   end
--- end
function M.get_state()
  return {
    level = level,
    passes = passes,
    errors = errors,
    skipped = skipped,
    focus_mode = focus_mode,
    test_results = test_results,
  }
end

--- Enum containing test status constants (PASS, FAIL, SKIP, PENDING).
---@field STATUS TestStatus
M.STATUS = TEST_STATUS

-- Add debug flag to test_definition module
local debug_mode = false

--- Set debug mode for test_definition module
--- This function enables or disables detailed debug output during test execution.
--- When debug mode is enabled, the system will print detailed information about
--- test execution, results, and internal state to help troubleshoot issues with
--- tests or the test framework itself.
---
---@param value boolean Whether to enable debug output
---@return TestDefinition The module instance (`M`) for method chaining.
---
---@usage
--- -- Enable debug mode to see detailed output
--- firmo.set_debug_mode(true)
---
--- -- Run tests with detailed debug information
--- describe("Debugging test suite", function()
---   it("shows detailed output in debug mode", function()
---     expect(true).to.be_truthy()
---   end)
--- end)
---
--- -- Disable debug mode when done troubleshooting
--- firmo.set_debug_mode(false)
function M.set_debug_mode(value)
  debug_mode = value == true
  return M
end

--- Add a test result to the collection
--- This function adds a structured test result to the internal results collection
--- and updates the test counters. It's primarily used internally by the test system
--- but can also be used by test reporters or extensions to record custom test results.
---
---@param result TestResult The test result object to add
---@return TestResult|nil result The added `TestResult` object, or `nil` if the input `result` was invalid.
---
---@usage
--- -- Custom test reporter
--- local function my_reporter(results)
---   for _, result in ipairs(results) do
---     if result.status == "pass" then
---       print(string.format("✓ %s (%.3fs)", result.name, result.execution_time or 0))
---     elseif result.status == "fail" then
---       print(string.format("✗ %s\n  %s", result.name, result.error_message or "Unknown error"))
---     else
---       print(string.format("- %s (%s)", result.name, result.status))
---     end
---   end
--- end
---
--- -- For custom test systems or extensions
--- local result = firmo.add_test_result({
---   status = "pass",
---   name = "External test",
---   path = {"External", "Integration", "API Test"},
---   path_string = "External / Integration / API Test",
---   execution_time = 0.125,
---   timestamp = os.time()
--- })
function M.add_test_result(result)
  if not result or type(result) ~= "table" then
    return nil
  end

  -- Ensure required fields
  result.status = result.status or TEST_STATUS.FAIL
  result.name = result.name or "unknown test"
  result.timestamp = result.timestamp or os.time()

  -- Add result to collection
  table.insert(test_results, result)

  -- Print debug output if enabled
  if debug_mode then
    local status_color = ""
    if result.status == TEST_STATUS.PASS then
      status_color = "\27[32m" -- green
    elseif result.status == TEST_STATUS.FAIL then
      status_color = "\27[31m" -- red
    else
      status_color = "\27[33m" -- yellow
    end

    print(
      string.format(
        "ADD RESULT: %s[%s]\27[0m %s (%s) %s",
        status_color,
        result.status:upper(),
        result.name,
        result.path_string or "",
        result.expect_error and "[expects error]" or ""
      )
    )
  end

  -- Update counters based on status
  if result.status == TEST_STATUS.PASS then
    passes = passes + 1
  elseif result.status == TEST_STATUS.FAIL then
    errors = errors + 1
  elseif result.status == TEST_STATUS.SKIP or result.status == TEST_STATUS.PENDING then
    skipped = skipped + 1
  end

  return result
end

-- Initialize and return the module
return M
