# CSV Formatter API Reference


The CSV formatter generates coverage and test results in Comma-Separated Values (CSV) format, providing structured tabular data suitable for spreadsheet analysis, data processing, and integration with external tools.

## Overview


The CSV formatter creates standards-compliant CSV files with these key features:


- Configurable column selection and ordering
- Header row customization
- Custom field separators and text delimiters
- Proper escaping of special characters
- Flexible data mapping for complex coverage data
- Multiple table output support
- Row and column filtering capabilities
- Performance optimizations for large datasets


## Class Reference


### Inheritance



```text
Formatter (Base)
  └── CSVFormatter
```



### Class Definition



```lua
---@class CSVFormatter : Formatter
---@field _VERSION string Version information
local CSVFormatter = Formatter.extend("csv", "csv")
```



## CSV Format Specification


The CSV formatter adheres to RFC 4180 with these key features:


- Each record appears on a separate line
- Fields are separated by commas (configurable)
- Fields containing delimiters, newlines, or quotes are enclosed in double quotes
- Double quotes within fields are escaped with a second double quote
- First row can optionally contain column headers

Example CSV output:


```csv
File,Total Lines,Covered Lines,Executed Lines,Coverage %
lib/module.lua,100,75,25,75.0
lib/other.lua,80,40,20,50.0
```



## Core Methods


### format(data, options)


Formats coverage or test results data into CSV format.


```lua
---@param data table Normalized coverage or test results data
---@param options table|nil Formatting options
---@return string csv CSV-formatted report
---@return table|nil error Error object if formatting failed
function CSVFormatter:format(data, options)
```



### format_coverage(data, options)


Specialized method for formatting coverage data into CSV.


```lua
---@param data table Normalized coverage data
---@param options table|nil Formatting options
---@return string csv CSV-formatted coverage report
---@return table|nil error Error object if formatting failed
function CSVFormatter:format_coverage(data, options)
```



### format_results(data, options)


Specialized method for formatting test results into CSV.


```lua
---@param data table Test results data
---@param options table|nil Formatting options
---@return string csv CSV-formatted test results
---@return table|nil error Error object if formatting failed
function CSVFormatter:format_results(data, options)
```



### generate(data, output_path, options)


Generate and save a complete CSV report.


```lua
---@param data table Coverage or test results data
---@param output_path string Path to save the report
---@param options table|nil Formatting options
---@return boolean success Whether the operation succeeded
---@return string|table result Path to saved file or error object
function CSVFormatter:generate(data, output_path, options)
```



## Configuration Options


The CSV formatter supports these configuration options:
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `delimiter` | string | `","` | Field separator character |
| `quote` | string | `"\""` | Field quote character |
| `escape_quote` | string | `"\""` | Character used to escape quotes |
| `newline` | string | `"\n"` | Record separator character(s) |
| `include_header` | boolean | `true` | Include header row |
| `columns` | table | *default set* | Columns to include (array or config table) |
| `include_line_data` | boolean | `false` | Include detailed line-level data |
| `include_function_data` | boolean | `false` | Include function-level data |
| `null_value` | string | `""` | String to use for null values |
| `decimal_places` | number | `2` | Number of decimal places for percentages |
| `sort_by` | string | `"path"` | Sort files by: "path", "coverage", or "name" |
| `sort_direction` | string | `"asc"` | Sort direction: "asc" or "desc" |
| `filter_min_coverage` | number | `0` | Minimum coverage % to include |
| `filter_max_coverage` | number | `100` | Maximum coverage % to include |
| `filter_pattern` | string | `nil` | Include only files matching pattern |
| `exclude_pattern` | string | `nil` | Exclude files matching pattern |
| `file_info_only` | boolean | `true` | Only include file-level info (summary) |
| `encoding` | string | `"utf8"` | Character encoding for the output |
| `bom` | boolean | `false` | Include BOM in UTF-8 output |
| `sanitize_paths` | boolean | `true` | Normalize path separators |

### Configuration Example



```lua
local reporting = require("lib.reporting")
reporting.configure_formatter("csv", {
  delimiter = ",",
  include_header = true,
  columns = {
    "path",
    "total_lines",
    "covered_lines", 
    "coverage_percent",
    "execution_percent"
  },
  decimal_places = 1,
  sort_by = "coverage_percent",
  sort_direction = "desc",
  filter_min_coverage = 50,
  filter_pattern = "^lib/"
})
```



## Column Configuration and Customization


### Standard Columns


Default file-level columns available:
| Column ID | Description | Type |
|-----------|-------------|------|
| `path` | File path | string |
| `name` | File name | string |
| `total_lines` | Total lines in file | number |
| `covered_lines` | Lines covered by assertions | number |
| `executed_lines` | Lines executed | number |
| `not_covered_lines` | Lines not covered | number |
| `coverage_percent` | Percentage of coverage | number |
| `execution_percent` | Percentage of execution | number |
| `functions_total` | Total functions | number |
| `functions_covered` | Functions covered | number |
| `functions_executed` | Functions executed | number |
| `functions_percent` | Function coverage percent | number |

### Line-Level Columns


Available when `include_line_data = true`:
| Column ID | Description | Type |
|-----------|-------------|------|
| `file_path` | File path | string |
| `line_number` | Line number | number |
| `executed` | Line executed | boolean |
| `covered` | Line covered | boolean |
| `execution_count` | Execution count | number |
| `content` | Line content | string |

### Function-Level Columns


Available when `include_function_data = true`:
| Column ID | Description | Type |
|-----------|-------------|------|
| `file_path` | File path | string |
| `function_name` | Function name | string |
| `start_line` | Starting line | number |
| `end_line` | Ending line | number |
| `executed` | Function executed | boolean |
| `covered` | Function covered | boolean |
| `execution_count` | Call count | number |

### Column Definition Options


Advanced column configuration with transformation:


```lua
reporting.configure_formatter("csv", {
  columns = {
    { id = "path", header = "File Path", transform = function(v) return v:gsub("^lib/", "") end },
    { id = "total_lines", header = "Total LOC" },
    { id = "coverage_percent", header = "Coverage %", transform = function(v) return string.format("%.0f%%", v) end },
    { id = "custom", header = "Status", value = function(file) 
      return file.summary.coverage_percent >= 80 and "Good" or "Needs Work" 
    end }
  }
})
```



## Data Mapping and Transformation


### Value Transformation


Transform values before output with the `transform` function:


```lua
-- Convert value to percentage with % sign
{ 
  id = "coverage_percent", 
  header = "Coverage", 
  transform = function(value) 
    return string.format("%.1f%%", value) 
  end 
}
-- Truncate long paths
{ 
  id = "path", 
  transform = function(value) 
    if #value > 30 then
      return "..." .. value:sub(-27)
    end
    return value
  end 
}
```



### Custom Value Generation


Generate custom values with the `value` function:


```lua
-- Add quality rating based on coverage
{ 
  id = "rating", 
  header = "Quality Rating",
  value = function(file) 
    local pct = file.summary.coverage_percent
    if pct >= 90 then return "Excellent"
    elseif pct >= 75 then return "Good"
    elseif pct >= 50 then return "Adequate"
    else return "Poor" end
  end 
}
-- Add file modified date from filesystem
{ 
  id = "modified_date", 
  header = "Last Modified",
  value = function(file)
    local fs = require("lib.tools.filesystem")
    return fs.get_last_modified(file.path)
  end 
}
```



## Integration with Spreadsheet Tools


### Microsoft Excel Integration



```lua
-- Configure for Excel compatibility
reporting.configure_formatter("csv", {
  delimiter = ",",
  quote = "\"",
  decimal_places = 2,
  include_header = true,
  bom = true  -- Add BOM for Excel UTF-8 detection
})
```



### Google Sheets Integration



```lua
-- Configure for Google Sheets
reporting.configure_formatter("csv", {
  delimiter = ",",
  quote = "\"",
  decimal_places = 2,
  include_header = true
})
```



### LibreOffice Calc Integration



```lua
-- Configure for LibreOffice Calc
reporting.configure_formatter("csv", {
  delimiter = ",",
  quote = "\"",
  decimal_places = 2,
  include_header = true,
  encoding = "utf8"
})
```



### Import Instructions


To import CSV reports into spreadsheet tools:


1. **Excel**: File → Open → Browse to your CSV file → Open → Select "Delimited" → Next → Check "Comma" → Finish
2. **Google Sheets**: File → Import → Upload → Select your CSV file → Import data
3. **LibreOffice Calc**: File → Open → Select your CSV file → Open → Select settings → OK


## Performance Considerations for Large Datasets


### Memory Usage Optimization


For large codebases, optimize memory usage:


```lua
-- Reduce memory usage for large codebases
reporting.configure_formatter("csv", {
  file_info_only = true,        -- Only include file summaries
  include_line_data = false,    -- Skip detailed line data
  include_function_data = false, -- Skip function data
  columns = {                   -- Minimize columns
    "path", 
    "total_lines", 
    "covered_lines", 
    "coverage_percent"
  }
})
```



### Processing Speed


The CSV formatter is optimized for speed with these techniques:


- Single-pass data processing
- Minimized table creation
- Pre-allocated string buffers
- Indexed field lookups
- Sorted once, accessed many times

For very large datasets (1000+ files):


```lua
-- Split output into multiple files
local file_count = 0
local csv_content = ""
local BATCH_SIZE = 500
for file_path, file_data in pairs(coverage_data.files) do
  -- Add file data to CSV content
  csv_content = csv_content .. format_file_csv_row(file_data)
  file_count = file_count + 1

  -- Write in batches of 500 files
  if file_count % BATCH_SIZE == 0 then
    local batch_num = math.floor(file_count / BATCH_SIZE)
    reporting.write_file(string.format("coverage-batch-%d.csv", batch_num), csv_content)
    csv_content = ""
  end
end
-- Write remaining files
if csv_content ~= "" then
  local batch_num = math.ceil(file_count / BATCH_SIZE)
  reporting.write_file(string.format("coverage-batch-%d.csv", batch_num), csv_content)
end
```



## Header Row Customization


### Custom Header Names


Override default header names:


```lua
reporting.configure_formatter("csv", {
  columns = {
    { id = "path", header = "Source File" },
    { id = "total_lines", header = "Total LOC" },
    { id = "coverage_percent", header = "Coverage Rate (%)" }
  }
})
```



### Disabling Header Row


Generate data-only CSV:


```lua
reporting.configure_formatter("csv", {
  include_header = false
})
```



### Localized Headers


Create localized headers for international teams:


```lua
-- Example with Spanish headers
reporting.configure_formatter("csv", {
  columns = {
    { id = "path", header = "Archivo Fuente" },
    { id = "total_lines", header = "Líneas Totales" },
    { id = "covered_lines", header = "Líneas Cubiertas" },
    { id = "coverage_percent", header = "Porcentaje de Cobertura" }
  }
})
```



## Custom Separators and Escaping


### Alternative Delimiters


For TSV (Tab-Separated Values) or other formats:


```lua
-- Configure as Tab-Separated Values (TSV)
reporting.configure_formatter("csv", {
  delimiter = "\t",
  quote = "\"",
  extension = "tsv" -- Optional hint for file extension
})
-- Configure as Semicolon-Separated Values (common in Europe)
reporting.configure_formatter("csv", {
  delimiter = ";",
  quote = "\""
})
```



### Custom Escaping Rules


For integration with specific tools:


```lua
-- Custom escaping for special tool
reporting.configure_formatter("csv", {
  quote = "'",                   -- Use single quotes
  escape_quote = "\\",           -- Escape with backslash
  newline = "\r\n",              -- Windows line endings
  null_value = "NULL"            -- Special null value
})
```



## Validation Rules and Error Handling


### Input Validation


The CSV formatter validates input data structure:


```lua
-- Check for required structure
if not data or type(data) ~= "table" then
  return nil, error_handler.validation_error("Invalid coverage data structure", {
    expected = "table",
    received = type(data),
    module = "csv_formatter"
  })
end
-- Check for files table
if not data.files or type(data.files) ~= "table" then
  return nil, error_handler.validation_error("Missing or invalid files table", {
    module = "csv_formatter",
    field = "files",
    data_type = type(data.files)
  })
end
```



### Error Response Example


Handling formatting errors:


```lua
local success, result_or_error = reporting.format_coverage(invalid_data, "csv")
if not success then
  print("Error category: " .. result_or_error.category)
  print("Error message: " .. result_or_error.message)
  if result_or_error.context then
    print("Context: ")
    for k, v in pairs(result_or_error.context) do
      print("  " .. k .. ": " .. tostring(v))
    end
  end
end
```



## Usage Examples


### Basic Coverage Report
