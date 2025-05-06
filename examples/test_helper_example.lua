--- Demonstrates the usage of the Firmo Test Helper module (`lib.tools.test_helper`).
---
--- This module provides utilities specifically designed for writing tests,
--- such as helpers for asserting errors, capturing errors for inspection,
--- managing temporary files/directories, and testing asynchronous errors.
---
--- @module examples.test_helper_example
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025

-- Import core Firmo test functions
local firmo = require("firmo")
local describe, it, expect, it_async = firmo.describe, firmo.it, firmo.expect, firmo.it_async

-- Import the module being demonstrated
local test_helper = require("lib.tools.test_helper")

-- Import dependencies needed for specific examples
local error_handler = require("lib.tools.error_handler")
local async = require("lib.async")

-- Define an async function that will fail after a short delay
local failing_async_fn = async.async(function() 
  async.await(10)
  error("Async failure!") 
end)

local function always_throws()
  error("Something unexpected happened!")
end

local function throws_with_code()
  error(error_handler.validation_error("Invalid ID: 123", { id = 123 }))
end

describe("Test Helper Examples", function()
  it("expect_error: asserts a function throws", function()
    -- This test passes because always_throws() does throw an error.
    local captured_err = test_helper.expect_error(always_throws)

    -- We can optionally inspect the captured error
    expect(captured_err).to.exist()
    expect(captured_err.category).to.equal(error_handler.CATEGORY.TEST_EXPECTED)
    expect(captured_err.message).to.match("Something unexpected happened!")
  end)

  it("expect_error: asserts error message matches pattern", function()
    -- This test passes because the error message matches the pattern "Invalid ID: %d+".
    local captured_err = test_helper.expect_error(throws_with_code, "Invalid ID: %d+")

    expect(captured_err).to.exist()
    expect(captured_err.message).to.match("Invalid ID: 123")
  end)

  it("with_error_capture: captures error object for inspection", function()
    -- Wrap the function that throws
    local wrapped_func = test_helper.with_error_capture(throws_with_code)

    -- Execute the wrapped function
    local result, err = wrapped_func()

    -- Assert that an error was captured and inspect its properties
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.category).to.equal(error_handler.CATEGORY.TEST_EXPECTED)
    expect(err.message).to.equal("Invalid ID: 123")

    -- Check the original error preserved in the 'cause' field
    expect(err.cause).to.exist()
    expect(err.cause.category).to.equal(error_handler.CATEGORY.VALIDATION)
    expect(err.cause.context.id).to.equal(123)
  end)

  it("with_temp_test_directory: runs code with temporary files", function()
    local files_map = { ["config.ini"] = "setting=value" } -- Explicitly set: filename=key, content=value

    local callback_executed = false
    local result = test_helper.with_temp_test_directory(files_map, function(dir_path, created_files, test_dir_obj) -- Use files_map
      callback_executed = true

      expect(dir_path).to.be.a("string")
      expect(#created_files).to.equal(1) -- Only one file created
      expect(test_dir_obj).to.be.a("table")

      -- Verify files were created using the helper object
      expect(test_dir_obj:file_exists("config.ini")).to.be_truthy() -- Check correct filename
      -- Removed check for non-existent subdir/data.log

      -- Read content back
      local content, read_err = test_dir_obj:read_file("config.ini") -- Read correct filename
      expect(read_err).to_not.exist() -- Use correct assertion
      expect(content).to.equal("setting=value")

      return "Callback Success"
    end)

    expect(callback_executed).to.be_truthy()
    expect(result).to.equal("Callback Success")
    -- The temporary directory and its contents are automatically cleaned up after this test.
  end)

  it_async("expect_async_error: asserts an async function fails", function()
    -- Assert that it fails within 50ms and check the error
    local captured_err = test_helper.expect_async_error(failing_async_fn, 50, "Async failure!")
    expect(captured_err).to.exist()
    expect(captured_err.category).to.equal(error_handler.CATEGORY.TEST_EXPECTED)
    expect(captured_err.message).to.match("Async failure!")
  end)
end)
