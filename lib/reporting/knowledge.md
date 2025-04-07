# Reporting Knowledge

## Purpose
Generate test and coverage reports in various formats.

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

-- Complex reporting scenario
local function generate_test_reports(results)
  -- Configure formatters
  local formatters = {
    html = require("lib.reporting.formatters.html"),
    json = require("lib.reporting.formatters.json"),
    junit = require("lib.reporting.formatters.junit")
  }
  
  -- Generate reports
  for format, formatter in pairs(formatters) do
    local output_file = string.format(
      "reports/%s/report.%s",
      format,
      formatter.extension
    )
    
    local success, err = error_handler.try(function()
      return formatter.generate(results, {
        output = output_file,
        include_source = true,
        pretty_print = true
      })
    end)
    
    if not success then
      logger.error("Report generation failed", {
        format = format,
        error = err
      })
    end
  end
end
```

## Custom Formatters
```lua
-- Create custom formatter
local MyFormatter = {
  name = "custom",
  extension = "txt"
}

function MyFormatter:format(results)
  local output = {
    summary = {
      total = results.total,
      passed = results.passed,
      failed = results.failed,
      skipped = results.skipped,
      duration = results.duration
    },
    tests = {}
  }
  
  for _, test in ipairs(results.tests) do
    table.insert(output.tests, {
      name = test.name,
      status = test.status,
      duration = test.duration,
      error = test.error
    })
  end
  
  return output
end

-- Register formatter
firmo.register_formatter("custom", MyFormatter)
```

## Error Handling
```lua
-- Report validation
local function validate_report_data(data)
  local validator = require("lib.reporting.validation")
  local valid, errors = validator.validate(data)
  
  if not valid then
    for _, err in ipairs(errors) do
      logger.error("Report validation error", {
        field = err.field,
        message = err.message
      })
    end
    return false
  end
  
  return true
end

-- Safe report generation
local function safe_generate_report(format, data, options)
  -- Validate data first
  if not validate_report_data(data) then
    return nil, error_handler.validation_error(
      "Invalid report data"
    )
  end
  
  -- Generate report
  local success, err = error_handler.try(function()
    return generate_report(format, data, options)
  end)
  
  if not success then
    return nil, err
  end
  
  return success
end
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