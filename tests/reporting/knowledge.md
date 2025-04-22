# Reporting Knowledge


## Purpose


Test report generation system and output formatting.

## Supported Formats



- **HTML** - Interactive reports with syntax highlighting
- **JSON** - Machine-readable data for integration
- **XML** - Standard JUnit/Cobertura XML for CI systems
- **TAP** - Test Anything Protocol for broader integration
- **CSV** - Spreadsheet-compatible test results
- **LCOV** - Standard coverage format for tools integration
- **Summary** - Concise console summary
- **Custom** - User-defined formatter support


## Report Generation



```lua
-- HTML coverage report
firmo.generate_coverage_report("html", {
  title = "Coverage Report",
  output = "coverage/index.html",
  include_source = true,
  threshold = 90,
  filters = {
    include = { "src/**/*.lua" },
    exclude = { "tests/" }
  }
})
-- JSON report with stats
firmo.generate_report("json", {
  output = "report.json",
  include_stats = true,
  pretty_print = true,
  include_source = false
})
-- Multiple formats at once
firmo.generate_reports({
  html = {
    output = "coverage/index.html",
    include_source = true
  },
  json = {
    output = "coverage.json",
    pretty_print = true
  },
  lcov = {
    output = "lcov.info"
  }
})
```



## Custom Formatters



```lua
-- Create custom formatter
local MyFormatter = {}
function MyFormatter:format(results)
  return {
    tests = results.tests,
    passed = results.passed,
    failed = results.failed,
    custom_field = "value"
  }
end
-- Register formatter
firmo.register_formatter("custom", MyFormatter)
-- Complex formatter example
local HTMLFormatter = {
  name = "html",
  file_extension = "html"
}
function HTMLFormatter:format(results)
  local template = [[
    <!DOCTYPE html>
    <html>
      <head><title>Test Results</title></head>
      <body>
        <h1>Test Results</h1>
        <div class="summary">
          <p>Total: ${total}</p>
          <p>Passed: ${passed}</p>
          <p>Failed: ${failed}</p>
        </div>
        <div class="details">
          ${test_details}
        </div>
      </body>
    </html>
  ]]

  -- Generate test details
  local details = {}
  for _, test in ipairs(results.tests) do
    table.insert(details, string.format(
      "<div class='test %s'>%s</div>",
      test.status,
      test.name
    ))
  end

  return template
    :gsub("${total}", results.total)
    :gsub("${passed}", results.passed)
    :gsub("${failed}", results.failed)
    :gsub("${test_details}", table.concat(details, "\n"))
end
```



## Report Validation



```lua
-- Validate report data
local validator = require("lib.reporting.validation")
local report_data = generate_report_data()
local valid, errors = validator.validate(report_data)
if not valid then
  for _, err in ipairs(errors) do
    logger.error("Validation error", {
      field = err.field,
      message = err.message
    })
  end
end
-- Schema validation
local schema = {
  type = "object",
  properties = {
    total = { type = "number" },
    passed = { type = "number" },
    failed = { type = "number" },
    tests = {
      type = "array",
      items = {
        type = "object",
        properties = {
          name = { type = "string" },
          status = { type = "string" }
        }
      }
    }
  }
}
local valid = validator.validate_schema(report_data, schema)
```



## Critical Rules



- Validate report data
- Handle large reports
- Clean up old reports
- Use streaming
- Handle timeouts
- Follow specs
- Document formats
- Test thoroughly


## Best Practices



- Use appropriate format
- Configure paths properly
- Handle large files
- Clean up old reports
- Validate data
- Stream large reports
- Monitor memory
- Handle errors
- Document formats
- Test thoroughly


## Performance Tips



- Stream large reports
- Use efficient formatters
- Clean up old files
- Handle memory limits
- Optimize HTML gen
- Batch operations
- Cache results
- Monitor resources
