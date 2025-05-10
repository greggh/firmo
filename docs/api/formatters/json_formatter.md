# JSON Formatter API Reference


The JSON formatter produces machine-readable coverage reports in structured JSON format, suitable for automated processing, CI/CD integration, and custom tooling.

## Overview


The JSON formatter generates standards-compliant, well-structured JSON coverage reports with these key features:


- Comprehensive coverage data in machine-readable format
- Configurable output formatting (pretty-printed or compact)
- Validated against a JSON schema
- Full hierarchical structure of coverage information
- Support for file, function, and line-level coverage data
- Metadata and summary statistics
- Options for data reduction to control file size


## Class Reference


### Inheritance



```text
Formatter (Base)
  └── JSONFormatter
```



### Class Definition



```lua
---@class JSONFormatter : Formatter
---@field _VERSION string Version information
local JSONFormatter = Formatter.extend("json", "json")
```



## Core Methods


### format(data, options)


Formats coverage data into JSON.


```lua
---@param data table Normalized coverage data
---@param options table|nil Formatting options
---@return string json JSON-formatted coverage report
---@return table|nil error Error object if formatting failed
function JSONFormatter:format(data, options)
```



### generate(data, output_path, options)


Generate and save a complete JSON report.


```lua
---@param data table Coverage data
---@param output_path string Path to save the report
---@param options table|nil Formatting options
---@return boolean success Whether the operation succeeded
---@return string|table result Path to saved file or error object
function JSONFormatter:generate(data, output_path, options)
```



## Configuration Options


The JSON formatter supports these configuration options:
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `pretty` | boolean | `false` | Enable pretty-printing with indentation |
| `indent` | string/number | `2` | Indentation level or string for pretty-print |
| `include_source` | boolean | `false` | Include source code in output |
| `include_line_content` | boolean | `false` | Include line content in output |
| `truncate_content` | boolean | `true` | Truncate long line content strings |
| `content_limit` | number | `100` | Max characters per line when truncating |
| `include_metadata` | boolean | `true` | Include metadata about the report |
| `include_execution_counts` | boolean | `true` | Include execution count data |
| `include_function_coverage` | boolean | `true` | Include function-level coverage |
| `include_details` | boolean | `true` | Include detailed line/function information |
| `minify` | boolean | `false` | Produce minified JSON (overrides pretty) |
| `null_value` | any | `null` | Value to use for JSON null |
| `compact_arrays` | boolean | `false` | Use compact array format for lines |

### Configuration Example



```lua
local reporting = require("lib.reporting")
reporting.configure_formatter("json", {
  pretty = true,              -- Make the output human-readable 
  indent = 4,                 -- Use 4 spaces for indentation
  include_source = false,     -- Don't include source code
  include_line_content = true, -- Include shortened content for lines
  truncate_content = true,    -- Truncate long lines
  content_limit = 80,         -- Limit content to 80 chars
  include_metadata = true     -- Include report metadata
})
```



## JSON Schema and Structure


The JSON formatter produces output conforming to this structure:


```json
{
  "metadata": {
    "version": "1.0.0",
    "timestamp": "2025-04-12T21:30:05Z",
    "generator": "firmo JSON formatter v1.2.3"
  },
  "summary": {
    "total_files": 10,
    "total_lines": 1500,
    "covered_lines": 850,
    "executed_lines": 300,
    "not_covered_lines": 350,
    "coverage_percent": 56.67,
    "execution_percent": 76.67
  },
  "files": {
    "lib/module.lua": {
      "path": "lib/module.lua",
      "name": "module.lua",
      "summary": {
        "total_lines": 150,
        "covered_lines": 85,
        "executed_lines": 30,
        "not_covered_lines": 35,
        "coverage_percent": 56.67,
        "execution_percent": 76.67
      },
      "lines": {
        "1": {
          "line_number": 1,
          "executed": true,
          "covered": true,
          "execution_count": 10,
          "content": "function add(a, b)"
        },
        "2": {
          "line_number": 2,
          "executed": true,
          "covered": false,
          "execution_count": 5,
          "content": "  return a + b"
        },
        "3": {
          "line_number": 3,
          "executed": false,
          "covered": false,
          "execution_count": 0,
          "content": "end"
        }
      },
      "functions": {
        "add": {
          "name": "add",
          "start_line": 1,
          "end_line": 3,
          "executed": true,
          "covered": true,
          "execution_count": 10
        }
      }
    }
  }
}
```



### Schema Validation


The JSON formatter validates its output against an internal schema to ensure:


- Required fields are present
- Field types match expected types
- Numeric ranges are valid (e.g., percentages are 0-100)
- Data consistency (e.g., line counts match summary statistics)


## Usage Example



```lua
local reporting = require("lib.reporting")
local coverage = require("lib.coverage")
-- Configure the JSON formatter
reporting.configure_formatter("json", {
  pretty = true,
  include_line_content = true
})
-- Run tests with coverage
coverage.start()
-- Run tests here...
coverage.stop()
-- Generate JSON report
local data = coverage.get_data()
local json_content = reporting.format_coverage(data, "json")
-- Save the report
reporting.write_file("coverage-report.json", json_content)
-- Or in one step:
reporting.save_coverage_report("coverage-report.json", data, "json")
```



## Error Handling


The JSON formatter handles these common issues:


1. **Invalid Data Structure**: Validates input and reports detailed error information
2. **JSON Serialization Errors**: Catches and reports errors during JSON encoding
3. **File System Issues**: Reports errors when saving to disk fails
4. **Large Data Sets**: Offers configuration to reduce output size for large codebases


### Error Response Example



```lua
local success, result_or_error = reporting.format_coverage(data, "json")
if not success then
  print("Error category: " .. result_or_error.category)
  print("Error message: " .. result_or_error.message)
  print("Context: " .. require("cjson").encode(result_or_error.context))
end
```



## Performance Considerations


### Output Size Management


For large codebases, consider these settings to reduce output size:


```lua
reporting.configure_formatter("json", {
  pretty = false,               -- Disable pretty-printing
  include_source = false,       -- Don't include source code
  include_line_content = false, -- Don't include line content
  include_details = false,      -- Include only summary information
  minify = true                 -- Produce minified output
})
```



### Memory Usage


The JSON formatter's memory usage is directly related to the size of your codebase and the configuration options. For very large projects:


1. Set `include_details = false` to only include summary information
2. Process the coverage report in chunks if necessary
3. Consider using `compact_arrays = true` to reduce memory overhead


### Processing Performance


JSON parsing performance in downstream tools may be affected by:


1. **Output Size**: Control with configuration options above
2. **String Encoding**: Control with `include_line_content` option
3. **Numeric Precision**: Fixed at standard JSON numeric precision


## CI/CD Integration


### GitHub Actions



```yaml

# .github/workflows/coverage.yml


jobs:
  test:
    runs-on: ubuntu-latest
    steps:


      - uses: actions/checkout@v2

      - name: Setup Lua

        uses: leafo/gh-actions-lua@v8

      - name: Run tests with coverage

        run: lua firmo.lua --coverage --format=json tests/

      - name: Upload coverage artifact

        uses: actions/upload-artifact@v2
        with:
          name: coverage-report
          path: coverage-reports/coverage-report.json

      - name: Process coverage

        run: ./scripts/process_coverage.sh
```



### Jenkins


To integrate with Jenkins:


1. Generate the JSON report in the appropriate format
2. Use the Jenkins Coverage API to publish the results
3. Consider the Cobertura plugin (may require conversion)

Example pipeline stage:


```groovy
stage('Test with Coverage') {
  steps {
    sh 'lua firmo.lua --coverage --format=json tests/'

    // Archive the JSON report as an artifact
    archiveArtifacts artifacts: 'coverage-reports/coverage-report.json'

    // Process with custom tool (example)
    sh './scripts/jenkins/process_coverage_json.sh'
  }
}
```



### Custom Processing


The JSON format enables custom analysis and visualization:


```lua
-- Custom coverage trend analysis script
local file = io.open("coverage-report.json", "r")
local content = file:read("*all")
file:close()
local cjson = require("cjson")
local data = cjson.decode(content)
-- Extract key metrics
local coverage_percent = data.summary.coverage_percent
local executed_percent = data.summary.execution_percent
local file_count = data.summary.total_files
-- Store trend data
store_trend_data({
  date = os.date("%Y-%m-%d"),
  coverage = coverage_percent,
  execution = executed_percent,
  files = file_count
})
```



## See Also



- [JSON Formatter Guide](../../guides/configuration-details/json_formatter.md)
- [Reporting API](../reporting.md)
- [Coverage API](../coverage.md)
- [CSV Formatter](./csv_formatter.md) - Alternative tabular format
