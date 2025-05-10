---@diagnostic disable: missing-parameter, param-type-mismatch
--- Quality Validation Module Tests
---
--- This comprehensive test suite verifies the quality validation system (`lib.quality`)
--- that ensures tests meet defined quality standards across multiple levels (1-5).
---
--- The tests verify:
--- - Quality module initialization and loading.
--- - Correct identification of test files meeting different quality levels.
--- - Enforcement of level requirements (e.g., assertions, coverage thresholds).
--- - Handling of missing files and invalid levels.
--- - Correct reporting of quality level names and constants.
--- Uses helper functions to create test files representing different quality levels,
--- `before`/`after` hooks for setup/teardown, and `test_helper` for error verification.
---
--- @author Firmo Team
--- @test
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")
local test_helper = require("lib.tools.test_helper")

local logging = require("lib.tools.logging")
local logger = logging.get_logger("test.quality")

-- Assume create_test_file function exists above this point in the actual file.
-- It's a local helper for this test suite and not part of the fix.
-- Example placeholder:
-- local function create_test_file(name, level, content)
--   -- ... creates a file in a temp directory ...
--   return "path/to/temp/" .. name
-- end

describe("Quality Module", function()
  local test_files = {}

  before(function()
    logger.debug("Finding test files in tests/quality directory", { pattern = "level_%d_test.lua" })
    for i = 1, 5 do
      local file_path = fs.join_paths("tests/quality", "level_" .. i .. "_test.lua")
      local file_exists, file_err = test_helper.with_error_capture(function()
        return fs.file_exists(file_path)
      end)()
      if file_exists then
        table.insert(test_files, file_path)
        logger.debug("Found test file", { file_path = file_path, quality_level = i })
      else
        logger.warn(
          "Could not find test file",
          { file_path = file_path, quality_level = i, error = file_err and tostring(file_err) or "File not found" }
        )
      end
    end
    expect(#test_files).to.be.at_least(
      1,
      "Failed to find any quality level test files. Ensure 'tests/quality/level_X_test.lua' files exist."
    ) -- MODIFIED
  end)

  after(function()
    logger.debug("Test complete - no cleanup needed for permanent test files", { file_count = #test_files })
    test_files = {}
  end)

  it("should load the quality module", function()
    local quality, load_error = test_helper.with_error_capture(function()
      return require("lib.quality")
    end)()
    expect(load_error).to_not.exist("Failed to load quality module: " .. tostring(load_error))
    expect(quality).to.exist()
    expect(type(quality)).to.equal("table")
    expect(type(quality.validate_test_quality)).to.equal("function")
    expect(type(quality.check_file)).to.equal("function")
  end)

  it("should validate test quality levels correctly", function()
    local quality, load_error = test_helper.with_error_capture(function()
      return require("lib.quality")
    end)()
    expect(load_error).to_not.exist("Failed to load quality module: " .. tostring(load_error))
    expect(quality).to.exist("Quality module is nil after require.")

    local _, config_error = test_helper.with_error_capture(function()
      return central_config.set("quality", { enabled = true, level = 5 })
    end)()
    expect(config_error).to_not.exist("Failed to set quality configuration: " .. tostring(config_error))

    if not quality.check_file then
      firmo.pending("Quality module check_file function not available")
      return
    end

    for _, file in ipairs(test_files) do
      local level = tonumber(file:match("level_(%d)_test.lua"))
      if level then
        local file_exists, file_exists_error = test_helper.with_error_capture(function()
          return fs.file_exists(file)
        end)()
        expect(file_exists_error).to_not.exist("Error checking if file exists: " .. tostring(file_exists_error))
        expect(file_exists).to.be_truthy("Test file does not exist: " .. file)

        for check_level = 1, level do
          local result, issues_or_err = test_helper.with_error_capture(function()
            return quality.check_file(file, check_level)
          end)()
          -- On success, quality.check_file now returns (true, {})
          expect(result).to.equal(true, "File " .. file .. " did not pass quality level " .. check_level .. " but should have.")
          expect(issues_or_err).to.be.a("table", "Issues should be a table even on success (empty).")
          expect(#issues_or_err).to.equal(0, "Expected no issues for file " .. file .. " at quality level " .. check_level .. " but issues were reported.")
        end
        if level < 5 then
          local result, issues_or_err = test_helper.with_error_capture(function()
            return quality.check_file(file, level + 1)
          end)()
          expect(result).to.equal(false, "File " .. file .. " should NOT have passed quality level " .. (level + 1) .. " due to naming convention.")
          expect(issues_or_err).to.be.a("table", "Expected issues_or_err to be a table for " .. file .. " at level " .. (level + 1))
          expect(#issues_or_err).to.equal(0, "Expected no specific validation issues when level_X file fails a higher level due to naming convention, but got " .. #issues_or_err .. " issues for " .. file .. " at level " .. (level+1) ..": " .. tostring(issues_or_err))
        end
      end
    end
  end)

  it("should handle missing files gracefully", function()
    local quality_module_loaded, quality = pcall(require, "lib.quality")
    expect(quality_module_loaded).to.be_truthy("Failed to load quality module for test.")
    expect(quality).to.exist("Quality module is nil after require.")

    local returned_value, issues_array = test_helper.with_error_capture(function()
      return quality.check_file("non_existent_file.lua", 1)
    end)()

    expect(returned_value).to.equal(false, "check_file should return false when file is missing.")
    expect(issues_array).to.be.a("table", "Issues details should be a table.")
    expect(#issues_array).to.be.at_least(1, "Should be at least one issue reported for a missing file.") -- MODIFIED
    if issues_array and #issues_array >= 1 and issues_array[1] then
      expect(issues_array[1].message).to.match(
        "^File '[^']+' not found%.$", -- More precise and anchored pattern
        "Issue message did not match for missing file."
      )
    end
  end)

  it("should use 90% as the coverage threshold requirement", function()
    local quality, load_error = test_helper.with_error_capture(function()
      return require("lib.quality")
    end)()
    expect(load_error).to_not.exist("Failed to load quality module: " .. tostring(load_error))
    expect(quality).to.exist("Quality module is nil after require.")

    local _, config_error = test_helper.with_error_capture(function()
      return central_config.set("quality", { enabled = true, level = 5 })
    end)()
    expect(config_error).to_not.exist("Failed to set quality configuration: " .. tostring(config_error))

    local level5_requirements, req_error = test_helper.with_error_capture(function()
      return quality.get_level_requirements(5)
    end)()
    expect(req_error).to_not.exist("Failed to get level requirements: " .. tostring(req_error))
    expect(level5_requirements).to.exist()
    expect(level5_requirements.test_organization.require_coverage_threshold).to.equal(90)
  end)

  it("should define quality level constants", function()
    local quality, load_error = test_helper.with_error_capture(function()
      return require("lib.quality")
    end)()
    expect(load_error).to_not.exist("Failed to load quality module: " .. tostring(load_error))
    expect(quality).to.exist()
    expect(type(quality.LEVEL_BASIC)).to.equal("number")
    expect(type(quality.LEVEL_STRUCTURED)).to.equal("number")
    expect(type(quality.LEVEL_COMPLETE)).to.equal("number")
    expect(type(quality.LEVEL_COMPREHENSIVE)).to.equal("number")
    expect(type(quality.LEVEL_ADVANCED)).to.equal("number")

    expect(quality.LEVEL_BASIC).to.equal(1)
    expect(quality.LEVEL_STRUCTURED).to.equal(2)
    expect(quality.LEVEL_COMPREHENSIVE).to.equal(3)
    expect(quality.LEVEL_ADVANCED).to.equal(4)
    expect(quality.LEVEL_COMPLETE).to.equal(5)
  end)

  it("should provide quality level names", function()
    local quality, load_error = test_helper.with_error_capture(function()
      return require("lib.quality")
    end)()
    expect(load_error).to_not.exist("Failed to load quality module: " .. tostring(load_error))
    expect(quality).to.exist("Quality module is nil after require.")

    if quality.get_level_name then
      for i = 1, 5 do
        local name, name_error = test_helper.with_error_capture(function()
          return quality.get_level_name(i)
        end)()
        expect(name_error).to_not.exist("Error getting level name for level " .. i .. ": " .. tostring(name_error))
        expect(name).to.exist()
        expect(type(name)).to.equal("string")
      end
      local invalid_name, invalid_error = test_helper.with_error_capture(function()
        return quality.get_level_name(999)
      end)()
      expect(invalid_error).to_not.exist("Error getting level name for invalid level 999")
      expect(invalid_name).to.equal("Not Assessed")
    else
      firmo.pending("get_level_name function not available")
    end
  end)

  it("should handle invalid quality levels gracefully", function()
    local quality_module_loaded, quality = pcall(require, "lib.quality")
    expect(quality_module_loaded).to.be_truthy("Failed to load quality module for test.")
    expect(quality).to.exist("Quality module is nil after require.")
    expect(test_files and #test_files > 0).to.be_truthy(
      "No test files available for testing invalid levels (before hook issue?)."
    )

    -- Test with an invalid quality level (negative)
    local returned_value_neg, issues_neg = test_helper.with_error_capture(function()
      return quality.check_file(test_files[1], -1)
    end)()

    expect(returned_value_neg).to.equal(false, "check_file should return false for invalid negative quality level.")
    expect(issues_neg).to.be.a("table", "Issues details for negative level should be a table.")
    expect(#issues_neg).to.be.at_least(1, "Should be at least one issue for negative level.") -- MODIFIED
    if issues_neg and #issues_neg >= 1 and issues_neg[1] then
      expect(issues_neg[1].message).to.match(
        "[Ii]nvalid quality level",
        "Issue message for negative level did not match."
      )
    end

    -- Test with an invalid quality level (too high)
    local returned_value_high, issues_high = test_helper.with_error_capture(function()
      return quality.check_file(test_files[1], 999)
    end)()

    expect(returned_value_high).to.equal(false, "check_file should return false for too high quality level.")
    expect(issues_high).to.be.a("table", "Issues details for high level should be a table.")
    expect(#issues_high).to.be.at_least(1, "Should be at least one issue for too high level.") -- MODIFIED
    if issues_high and #issues_high >= 1 and issues_high[1] then
      expect(issues_high[1].message).to.match("[Ii]nvalid quality level", "Issue message for high level did not match.")
    end
  end)

  logger.info("Quality module tests completed", { status = "success", test_group = "quality" })
end)
