# Formatters Knowledge

## Purpose
Output test and coverage results in various standardized formats.

## Formatter Implementation
```lua
-- Basic formatter structure
local MyFormatter = {
  name = "custom",
  extension = "txt",
  description = "Custom test result format"
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

-- Complex HTML formatter
local HTMLFormatter = {
  name = "html",
  extension = "html",
  description = "HTML test report formatter"
}

function HTMLFormatter:format(results)
  -- Load template
  local template = self:load_template()
  
  -- Generate test details
  local details = {}
  for _, test in ipairs(results.tests) do
    local status_class = test.status == "passed" and "success" or "failure"
    table.insert(details, string.format([[
      <div class="test %s">
        <h3>%s</h3>
        <div class="duration">%0.3fs</div>
        %s
      </div>
    ]], status_class, test.name, test.duration,
        test.error and string.format([[
          <div class="error">
            <pre>%s</pre>
          </div>
        ]], test.error) or ""
    ))
  end
  
  -- Apply template
  return template
    :gsub("${title}", results.title or "Test Results")
    :gsub("${total}", results.total)
    :gsub("${passed}", results.passed)
    :gsub("${failed}", results.failed)
    :gsub("${details}", table.concat(details, "\n"))
end
```

## Built-in Formatters
```lua
-- HTML coverage report
local html = require("formatters.html")
html.generate({
  title = "Coverage Report",
  include_source = true,
  theme = "light"
})

-- JSON output
local json = require("formatters.json")
json.format({
  pretty = true,
  include_source = false
})

-- TAP output
local tap = require("formatters.tap")
tap.format({
  include_yaml = true
})

-- JUnit XML
local junit = require("formatters.junit")
junit.format({
  include_system_out = true
})

-- LCOV coverage
local lcov = require("formatters.lcov")
lcov.format({
  include_branches = true
})
```

## Error Handling
```lua
-- Formatter error handling
function MyFormatter:format(results)
  -- Validate input
  if not results or type(results) ~= "table" then
    return nil, error_handler.validation_error(
      "Invalid results data",
      { provided_type = type(results) }
    )
  end
  
  -- Handle errors during formatting
  local success, output = error_handler.try(function()
    return self:do_format(results)
  end)
  
  if not success then
    return nil, error_handler.format_error(
      "Formatting failed",
      { error = output }
    )
  end
  
  return output
end

-- Resource cleanup
local function with_temp_file(callback)
  local path = fs.temp_file()
  local result, err = error_handler.try(function()
    return callback(path)
  end)
  
  fs.delete_file(path)
  return result, err
end
```

## Critical Rules
- Follow format specs
- Handle large files
- Stream output
- Clean up temp files
- Validate input data
- Document formats
- Test thoroughly
- Monitor performance

## Best Practices
- Stream large reports
- Handle memory limits
- Clean up temp files
- Validate input data
- Follow specs exactly
- Document format
- Handle errors
- Test thoroughly
- Monitor performance
- Use helpers

## Performance Tips
- Use streaming
- Minimize memory
- Clean up promptly
- Optimize large files
- Handle timeouts
- Cache results
- Batch operations
- Monitor resources