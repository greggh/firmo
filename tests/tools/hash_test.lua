-- Hash module tests
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local hash = require("lib.tools.hash")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect

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
    test_dir.create_file("test.txt", content)

    -- Hash the file
    local file_hash = hash.hash_file(test_dir.path .. "/test.txt")
    expect(file_hash).to.exist()
    expect(file_hash).to.equal(hash.hash_string(content))
  end)

  it("should handle missing files gracefully", function()
    local hash_str, err = hash.hash_file("nonexistent.txt")
    expect(hash_str).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("No such file or directory")
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
