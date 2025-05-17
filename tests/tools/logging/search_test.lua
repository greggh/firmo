---@diagnostic disable: missing-parameter, param-type-mismatch
--- Logging Search Module Tests
---
--- Tests the functionality of the log search module (`lib.tools.logging.search`), including:
--- - Searching logs by level, module, and message pattern (`search_logs`).
--- - Limiting search results (`limit` option).
--- - Generating statistics about log files (`get_log_stats`).
--- - Exporting logs to different formats (CSV) (`export_logs`).
--- - Creating log processors (`get_log_processor`).
--- Uses a `before` hook to create sample text and JSON log files for testing.
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
---@type fun(callback: function) before Setup function that runs before each test
local before = firmo.before
---@type fun(callback: function) after Teardown function that runs after each test
local after = firmo.after

local log_search = require("lib.tools.logging.search")
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")

describe("Logging Search Module", function()
  local test_files = {}

  -- Create a sample log file for testing
  before(function()
    local test_dir = test_helper.create_temp_test_directory()

    local log_content = [[
2025-03-26 14:32:45 | ERROR | database | Connection failed (host=db.example.com, port=5432, error=Connection refused)
2025-03-26 14:32:50 | WARN | authentication | Failed login attempt (username=user123, ip_address=192.168.1.1, attempt=3)
2025-03-26 14:33:00 | INFO | application | Application started (version=1.0.0, environment=production)
2025-03-26 14:33:15 | DEBUG | request | Processing request (request_id=req-12345, path=/api/users, method=GET)
2025-03-26 14:33:20 | ERROR | payment | Transaction failed (transaction_id=tx-67890, amount=99.99, currency=USD, reason=insufficient_funds)
]]

    local file_path = test_dir:create_file("sample.log", log_content)
    table.insert(test_files, file_path)

    -- Create a JSON log file
    local json_content = [[
{"timestamp":"2025-03-26T14:32:45","level":"ERROR","module":"database","message":"Connection failed","params":{"host":"db.example.com","port":5432,"error":"Connection refused"}}
{"timestamp":"2025-03-26T14:32:50","level":"WARN","module":"authentication","message":"Failed login attempt","params":{"username":"user123","ip_address":"192.168.1.1","attempt":3}}
{"timestamp":"2025-03-26T14:33:00","level":"INFO","module":"application","message":"Application started","params":{"version":"1.0.0","environment":"production"}}
]]

    local json_path = test_dir:create_file("sample.json", json_content)
    table.insert(test_files, json_path)
  end)

  it("searches logs by level", function()
    local results = log_search.search_logs({
      log_file = test_files[1],
      level = "ERROR",
    })

    expect(results).to.exist()
    expect(results.entries).to.be.a("table")
    expect(#results.entries).to.equal(2) -- Two ERROR logs in the sample

    for _, entry in ipairs(results.entries) do
      expect(entry.level).to.equal("ERROR")
    end
  end)

  it("searches logs by module", function()
    local results = log_search.search_logs({
      log_file = test_files[1],
      module = "database",
    })

    expect(results).to.exist()
    expect(results.entries).to.be.a("table")
    expect(#results.entries).to.equal(1) -- One database log in the sample
    expect(results.entries[1].module).to.equal("database")
  end)

  it("searches logs by message pattern", function()
    local results = log_search.search_logs({
      log_file = test_files[1],
      message_pattern = "failed",
    })

    expect(results).to.exist()
    expect(results.entries).to.be.a("table")
    expect(#results.entries).to.be_greater_than(0)

    for _, entry in ipairs(results.entries) do
      expect(entry.message:lower():find("failed")).to.exist("Message should contain 'failed'")
    end
  end)

  it("limits search results", function()
    local results = log_search.search_logs({
      log_file = test_files[1],
      limit = 2,
    })

    expect(results).to.exist()
    expect(results.entries).to.be.a("table")
    expect(#results.entries).to.equal(2) -- Limited to 2 results
    expect(results.truncated).to.be_truthy()
  end)

  it("gets log statistics", function()
    local stats = log_search.get_log_stats(test_files[1])

    expect(stats).to.exist()
    expect(stats.total_entries).to.equal(5)
    expect(stats.by_level).to.exist()
    expect(stats.by_level.ERROR).to.equal(2)
    expect(stats.by_module).to.exist()
    expect(stats.by_module.database).to.equal(1)
    expect(stats.errors).to.equal(2) -- Two ERROR logs
    expect(stats.warnings).to.equal(1) -- One WARN log
  end)

  it("exports logs to different formats", function()
    local test_dir = test_helper.create_temp_test_directory()
    local export_file = test_dir:path() .. "/export.csv"
    table.insert(test_files, export_file)

    local result = log_search.export_logs(test_files[1], export_file, "csv")

    expect(result).to.exist()
    expect(result.entries_processed).to.be_greater_than(0)
    expect(result.output_file).to.equal(export_file)

    -- Verify file exists and has CSV format
    local content = fs.read_file(export_file)
    expect(content).to.be.a("string")
    expect(content:sub(1, 10)).to.match("timestamp") -- Should have a header row
  end)

  it("creates a log processor", function()
    local test_dir = test_helper.create_temp_test_directory()
    local output_file = test_dir:create_file("processor_output.json", "")
    table.insert(test_files, output_file)

    local processor = log_search.get_log_processor({
      output_file = output_file,
      format = "json",
      level = "ERROR",
    })

    expect(processor).to.exist()
    expect(processor.process).to.be.a("function")
    expect(processor.close).to.be.a("function")

    -- Test processing a log entry
    local processed = processor.process({
      timestamp = "2025-03-26T14:32:45",
      level = "ERROR",
      module = "test",
      message = "Test message",
    })

    expect(processed).to.be_truthy()

    -- Close the processor
    processor.close()

    -- Verify file exists
    expect(fs.file_exists(output_file)).to.be_truthy()
  end)
end)
