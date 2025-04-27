---@diagnostic disable: missing-parameter, param-type-mismatch
--- Test Discovery Functionality Tests
---
--- Verifies the file discovery and execution features of Firmo, including:
--- - `firmo.discover` function for finding test files based on path and pattern.
--- - Handling of invalid directory paths and patterns.
--- - `firmo.run_discovered` function for running tests found by `discover`.
--- - Correct error propagation when a discovered test fails.
--- - Recursive discovery (`discover` with `true` flag).
--- - Uses `test_helper` and `filesystem` for temporary file creation and cleanup.
---
--- @author Firmo Team
--- @test
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

local test_helper = require("lib.tools.test_helper")
local fs = require("lib.tools.filesystem")

describe("Test Discovery", function()
  it("has discovery function", function()
    expect(firmo.discover).to.be.a("function")
    expect(firmo.run_discovered).to.be.a("function")
    expect(firmo.cli_run).to.be.a("function")
  end)

  it("can find test files", function()
    -- Use error capture for file discovery
    local result, err = test_helper.with_error_capture(function()
      return firmo.discover("./tests", "*_test.lua")
    end)()

    expect(err).to_not.exist("Failed to discover test files")
    expect(result).to.exist()
    expect(#result.files).to.be_greater_than(0)
    -- At minimum, this file should be found
    local this_file_found = false
    for _, file in ipairs(result) do
      if file:match("discovery_test.lua") then
        this_file_found = true
        break
      end
    end

    expect(this_file_found).to.be_truthy()
  end)

  it("handles invalid directory paths gracefully", { expect_error = true }, function()
    -- Try to discover in a non-existent directory
    local result, err = test_helper.with_error_capture(function()
      return firmo.discover("./nonexistent_directory", "*_test.lua")
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("directory")
  end)

  it("handles invalid pattern gracefully", { expect_error = true }, function()
    -- Try to discover with an invalid pattern
    local result, err = test_helper.with_error_capture(function()
      return firmo.discover("./tests", "[invalid-pattern")
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("pattern")
  end)

  it("can run discovered tests", { expect_error = true }, function()
    -- Create a temporary test file that will fail
    local temp_dir = "/tmp/firmo_discovery_test"
    local temp_file = fs.join_paths(temp_dir, "temp_failing_test.lua")

    -- Ensure directory exists
    local dir_result, dir_err = test_helper.with_error_capture(function()
      return fs.ensure_directory_exists(temp_dir)
    end)()

    expect(dir_err).to_not.exist("Failed to create temp directory")

    -- Create failing test file
    local write_result, write_err = test_helper.with_error_capture(function()
      return fs.write_file(
        temp_file,
        [[
        local firmo = require("firmo")
        local describe, it, expect = firmo.describe, firmo.it, firmo.expect

        describe("Failing Test", function()
          it("should fail", function()
            expect(false).to.be_truthy()
          end)
        end)
      ]]
      )
    end)()

    expect(write_err).to_not.exist("Failed to write temp test file")

    -- Try to run the failing test
    local run_result, run_err = test_helper.with_error_capture(function()
      return firmo.run_discovered(temp_dir, "temp_*.lua")
    end)()

    -- Should fail because the test intentionally fails
    expect(run_result).to_not.exist()
    expect(run_err).to.exist()

    -- Clean up
    local cleanup_result, cleanup_err = test_helper.with_error_capture(function()
      return fs.delete_directory(temp_dir)
    end)()

    if not cleanup_result and cleanup_err then
      firmo.log.warn("Failed to clean up temp directory", { directory = temp_dir, error = cleanup_err })
    end
  end)

  it("handles recursive discovery correctly", function()
    -- Use error capture for recursive discovery
    local result, err = test_helper.with_error_capture(function()
      return firmo.discover("./tests", "*_test.lua", true)
    end)()

    expect(err).to_not.exist("Failed to discover test files recursively")
    expect(result).to.exist()
    expect(#result.files).to.be_greater_than(0)
    -- Should find tests in subdirectories
    local found_subdir_test = false
    for _, file in ipairs(result) do
      if file:match("tests/[^/]+/[^/]+_test.lua") then
        found_subdir_test = true
        break
      end
    end

    expect(found_subdir_test).to.be_truthy("Failed to find tests in subdirectories")
  end)
end)
