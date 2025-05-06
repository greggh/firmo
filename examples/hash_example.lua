--- This example demonstrates the `lib.tools.hash` module, which provides
--- utilities for generating hash digests for strings and files. It showcases:
-- - Hashing strings using `hash.hash_string()`.
-- - Hashing file contents using `hash.hash_file()`.
-- - Using hashes for simple change detection.
-- - Using hashes as keys in a basic caching system simulation.
--
-- @module examples.hash_example
-- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
-- @see lib.tools.hash
-- @see lib.tools.test_helper
-- @usage
-- Run this example directly: lua examples/hash_example.lua
--

local hash = require("lib.tools.hash")
local test_helper = require("lib.tools.test_helper")
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("HashExample")

-- Create a temporary directory managed by test_helper for automatic cleanup
local test_dir = test_helper.create_temp_test_directory("hash_example_")

-- Example 1: Basic string hashing
logger.info("\nExample 1: Basic String Hashing")
logger.info("-------------------------------")

local str = "Hello, world!"
local str_hash = hash.hash_string(str)
print("String:", str)
print("Hash:", str_hash)

-- Example 2: File hashing
logger.info("\nExample 2: File Hashing")
logger.info("----------------------")

-- Create a test file
local file_content = "This is a test file with content." -- Use single line
--[[
This is a test file
with multiple lines
of content.
]]
test_dir.create_file("test.txt", file_content)

-- Hash the file
local file_path_for_hash = test_dir.path_for("test.txt") or (test_dir.path .. "/test.txt")
local file_hash = hash.hash_file(file_path_for_hash)
print("File content:", file_content:gsub("\n", "\\n"))
print("File hash:", file_hash)

-- Example 3: Change detection
logger.info("\nExample 3: Change Detection")
logger.info("-------------------------")

-- Create a file
local original_content = "Original content"
local file_path = test_dir.path .. "/watched.txt"
test_dir.create_file("watched.txt", original_content)

-- Get original hash
local original_hash = hash.hash_file(file_path)
print("Original content:", original_content)
print("Original hash:", original_hash)

-- Modify the file
local new_content = "Modified content"
test_dir.write_file("watched.txt", new_content)

-- Get new hash
local new_hash = hash.hash_file(file_path)
print("Modified content:", new_content)
print("Modified hash:", new_hash)
print("File changed:", original_hash ~= new_hash)

-- Example 4: Simple caching system
logger.info("\nExample 4: Simple Caching System")
logger.info("------------------------------")

-- Create a simple cache
local cache = {}

--- Simulates an expensive computation based on input string length.
-- This function's results will be cached in the example.
--- @param input string The input string.
--- @return number The computed result (length of input plus a large constant).
--- @within examples.hash_example
local function compute_expensive_result(input)
  -- Simulate expensive computation
  local result = 0
  for i = 1, 1000000 do
    result = result + i
  end
  return result + #input
end

--- Retrieves a result for the given input, using a simple hash-based cache.
-- If the result for the input's hash is not in the cache, it computes it
--- @param input string The input string to get the result for.
--- @return number The cached or newly computed result.
--- @within examples.hash_example
local function get_cached_result(input)
  local input_hash = hash.hash_string(input)
  if not cache[input_hash] then
    print("Cache miss for:", input)
    cache[input_hash] = compute_expensive_result(input)
  else
    print("Cache hit for:", input)
  end
  return cache[input_hash]
end

-- First call (cache miss)
local result1 = get_cached_result("test input")
print("Result:", result1)

-- Second call (cache hit)
local result2 = get_cached_result("test input")
print("Result:", result2)

-- Different input (cache miss)
local result3 = get_cached_result("different input")
print("Result:", result3)

logger.info("\nHash module example completed successfully.")
