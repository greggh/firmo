-- Logging Search Module Tests
-- Tests for the log search module functionality

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local log_search = require("lib.tools.logging.search")
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.temp_file")

describe("Logging Search Module", function()
  local test_files = {}

  -- Create a sample log file for testing
  before(function()
    local log_content = [[
2025-03-26 14:32:45 | ERROR | database | Connection failed (host=db.example.com, port=5432, error=Connection refused)
2025-03-26 14:32:50 | WARN | authentication | Failed login attempt (username=user123, ip_address=192.168.1.1, attempt=3)
2025-03-26 14:33:00 | INFO | application | Application started (version=1.0.0, environment=production)
2025-03-26 14:33:15 | DEBUG | request | Processing request (request_id=req-12345, path=/api/users, method=GET)
2025-03-26 14:33:20 | ERROR | payment | Transaction failed (transaction_id=tx-67890, amount=99.99, currency=USD, reason=insufficient_funds)
]]

    local file_path, err = temp_file.create_with_content(log_content, "log")
    expect(err).to_not.exist()
    table.insert(test_files, file_path)

    -- Create a JSON log file
    local json_content = [[
{"timestamp":"2025-03-26T14:32:45","level":"ERROR","module":"database","message":"Connection failed","params":{"host":"db.example.com","port":5432,"error":"Connection refused"}}
{"timestamp":"2025-03-26T14:32:50","level":"WARN","module":"authentication","message":"Failed login attempt","params":{"username":"user123","ip_address":"192.168.1.1","attempt":3}}
{"timestamp":"2025-03-26T14:33:00","level":"INFO","module":"application","message":"Application started","params":{"version":"1.0.0","environment":"production"}}
]]

    local json_path, json_err = temp_file.create_with_content(json_content, "json")
    expect(json_err).to_not.exist()
    table.insert(test_files, json_path)
  end)

  -- Clean up test files after all tests
  after(function()
    for _, file_path in ipairs(test_files) do
      temp_file.remove(file_path)
    end
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
      expect(entry.message:lower()).to.equal("failed")
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
    local export_file, err = temp_file.create_temp_file()
    expect(err).to_not.exist()
    table.insert(test_files, export_file)

    local result = log_search.export_logs(test_files[1], export_file, "csv")

    expect(result).to.exist()
    expect(result.entries_processed).to.equal(5)
    expect(result.output_file).to.equal(export_file)

    -- Verify file exists and has CSV format
    local content = fs.read_file(export_file)
    expect(content).to.be.a("string")
    expect(content:sub(1, 10)).to.match("timestamp") -- Should have a header row
  end)

  it("creates export adapters", function()
    local adapter = log_search.create_export_adapter("logstash", {
      application_name = "test_app",
      environment = "test",
    })

    expect(adapter).to.be.a("function")

    -- Test the adapter with a log entry
    local log_entry = {
      timestamp = "2025-03-26T14:32:45",
      level = "ERROR",
      module = "test",
      message = "Test message",
    }

    local formatted = adapter(log_entry)
    expect(formatted).to.be.a("table")
    expect(formatted.application).to.equal("test_app")
    expect(formatted.environment).to.equal("test")
    expect(formatted.message).to.equal("Test message")
  end)

  it("creates a log processor", function()
    local output_file, err = temp_file.create_temp_file()
    expect(err).to_not.exist()
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

  -- Add more tests for other search functionality
end)
