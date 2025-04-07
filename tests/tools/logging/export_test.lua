-- Logging Export Module Tests
-- Tests for the log export module functionality

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local log_export = require("lib.tools.logging.export")
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.temp_file")
local test_helper = require("lib.tools.test_helper")

describe("Logging Export Module", function()
  local log_file_path -- Store log file path from before hook

  -- Sample log entries for testing
  local test_log_entries = {
    {
      timestamp = "2025-03-26T14:32:45",
      level = "ERROR",
      module = "database",
      message = "Connection failed",
      params = {
        host = "db.example.com",
        port = 5432,
        error = "Connection refused",
      },
    },
    {
      timestamp = "2025-03-26T14:32:50",
      level = "WARN",
      module = "authentication",
      message = "Failed login attempt",
      params = {
        username = "user123",
        ip_address = "192.168.1.1",
        attempt = 3,
      },
    },
  }

  -- Create a sample log file for testing
  before(function()
    local log_content = [[
2025-03-26 14:32:45 | ERROR | database | Connection failed (host=db.example.com, port=5432, error=Connection refused)
2025-03-26 14:32:50 | WARN | authentication | Failed login attempt (username=user123, ip_address=192.168.1.1, attempt=3)
2025-03-26 14:33:00 | INFO | application | Application started (version=1.0.0, environment=production)
]]

    local test_dir = test_helper.create_temp_test_directory()
    log_file_path = test_dir.create_file("sample.log", log_content)
  end)


  it("lists supported platforms", function()
    local platforms = log_export.get_supported_platforms()

    expect(platforms).to.be.a("table")
    expect(#platforms).to.be_greater_than(0)

    -- Check for major platforms
    local has_elasticsearch = false
    local has_splunk = false
    local has_datadog = false

    for _, platform in ipairs(platforms) do
      if platform == "elasticsearch" then
        has_elasticsearch = true
      end
      if platform == "splunk" then
        has_splunk = true
      end
      if platform == "datadog" then
        has_datadog = true
      end
    end

    expect(has_elasticsearch).to.be_truthy()
    expect(has_splunk).to.be_truthy()
    expect(has_datadog).to.be_truthy()
  end)

  it("exports logs to different platform formats", function()
    local platforms = log_export.get_supported_platforms()

    for _, platform in ipairs(platforms) do
      local formatted, err = log_export.export_to_platform(test_log_entries, platform, {
        service_name = "test_service",
        environment = "test",
      })

      expect(err).to_not.exist()
      expect(formatted).to.be.a("table")
      expect(#formatted).to.equal(#test_log_entries)
    end
  end)

  it("creates platform configuration files", function()
    local test_dir = test_helper.create_temp_test_directory()
    local config_file = test_dir.create_file("platform_config.txt", "")

    local result, err = log_export.create_platform_config("elasticsearch", config_file, {
      es_host = "localhost:9200",
    })

    expect(err).to_not.exist()
    expect(result).to.exist()
    expect(result.config_file).to.equal(config_file)

    -- Verify file was created
    expect(fs.file_exists(config_file)).to.be_truthy()

    -- Check content
    local content = fs.read_file(config_file)
    expect(content).to.be.a("string")
    expect(content).to.match("elasticsearch")
  end)

  it("converts log files to platform formats", function()
    local test_dir = test_helper.create_temp_test_directory()
    local platform_file = test_dir.create_file("platform_output.txt", "")

    local result, err = log_export.create_platform_file(
      log_file_path, -- The log file created in before()
      "logstash",
      platform_file,
      {
        source_format = "text",
        application_name = "test_app",
        environment = "test",
      }
    )

    expect(err).to_not.exist()
    expect(result).to.exist()
    expect(result.entries_processed).to.be_greater_than(0)
    expect(result.output_file).to.equal(platform_file)

    -- Verify file content
    local content = fs.read_file(platform_file)
    expect(content).to.be.a("string")
    expect(content).to.match("test_app") -- Should include our application name
  end)

  it("creates real-time log exporters", function()
    local exporter, err = log_export.create_realtime_exporter("datadog", {
      service = "test_service",
      environment = "test",
      tags = { "test" },
    })

    expect(err).to_not.exist()
    expect(exporter).to.exist()
    expect(exporter.export).to.be.a("function")
    expect(exporter.platform).to.equal("datadog")
    expect(exporter.http_endpoint).to.exist()

    -- Test exporting a log entry
    local formatted = exporter.export(test_log_entries[1])
    expect(formatted).to.be.a("table")
    expect(formatted.service).to.equal("test_service")
  end)

  it("handles invalid platform gracefully", function()
    local formatted, err = log_export.export_to_platform(test_log_entries, "invalid_platform", {})

    expect(formatted).to_not.exist()
    expect(err).to.exist()
    expect(err).to.match("Unsupported platform")
  end)

  -- Add more tests for other export functionality
end)
