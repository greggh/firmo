--- Hash Module Tests
---
--- Verifies the functionality of the `lib.tools.hash` module, including:
--- - Consistent hashing of identical strings (`hash_string`).
--- - Different hashes for different strings.
--- - Correct hashing of file content (`hash_file`) compared to string hash.
--- - Graceful error handling for non-existent files.
--- - Correct input type validation for `hash_string`.
--- - Handling of empty and long strings.
--- Uses `test_helper` for error verification and temporary file management.
---
--- @author Firmo Team
--- @test

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect

local test_helper = require("lib.tools.test_helper")
local hash = require("lib.tools.hash")

describe("Hash Module", function()
  it("should hash strings consistently", function()
    -- Same string should produce same hash
    local str = "Hello, world!"
    local hash1 = hash.hash_string(str)
    local hash2 = hash.hash_string(str)
    expect(hash1).to.equal(hash2)

    -- Different strings should produce different hashes
    local hash3 = hash.hash_string("Different string")
    expect(hash3).to_not.equal(hash1)
  end)

  it("should validate input types", { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      return hash.hash_string(123)
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("must be a string")
  end)

  it("should hash files correctly", function()
    -- Create a test file
    local test_dir = test_helper.create_temp_test_directory()
    local content = "Test file content"
    test_dir:create_file("test.txt", content)

    -- Hash the file
    local file_hash = hash.hash_file(test_dir:path() .. "/test.txt")
    expect(file_hash).to.exist()
    expect(file_hash).to.equal(hash.hash_string(content))
  end)

  it("should handle missing files gracefully", { expect_error = true }, function()
    local hash_str, err = hash.hash_file("nonexistent.txt")
    expect(hash_str).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("Failed to read file for hashing")
    expect(err.context).to.exist()
    expect(err.context.path).to.equal("nonexistent.txt")
    expect(err.context.operation).to.equal("hash_file")
    expect(err.context.original_error).to.exist()
  end)
  it("should handle empty strings", function()
    local empty_hash = hash.hash_string("")
    expect(empty_hash).to.exist()
    expect(empty_hash).to.match("^%x+$") -- Should be hex string
  end)

  it("should handle long strings", function()
    -- Create a long string
    local long_str = string.rep("test", 1000)
    local long_hash = hash.hash_string(long_str)
    expect(long_hash).to.exist()
    expect(long_hash).to.match("^%x+$") -- Should be hex string
  end)
end)
