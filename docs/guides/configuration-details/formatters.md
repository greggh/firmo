# Coverage Report Formatters


Firmo supports multiple output formats for coverage reports through a class-based architecture. Each formatter extends from a base Formatter class and has specific configuration options and capabilities. This guide covers all available formatters, their configuration settings, and how to create custom formatters.
> 📌 **Note:** All formatters use the central configuration system. Configuration should always be applied through the `central_config` module, command-line flags, or the `.firmo-config.lua` file.

## Table of Contents



- [Overview](#overview)
- [Formatter Architecture](#formatter-architecture)
- [Base Formatter Configuration](#base-formatter-configuration)
- [Formatter Configuration](#formatter-configuration)
- [HTML Formatter](#html-formatter)
- [JSON Formatter](#json-formatter)
- [LCOV Formatter](#lcov-formatter)
- [Cobertura Formatter](#cobertura-formatter)
- [Summary Formatter](#summary-formatter)
- [JUnit Formatter](#junit-formatter)
- [TAP Formatter](#tap-formatter)
- [CSV Formatter](#csv-formatter)
- [Multiple Formatters](#multiple-formatters)
- [Creating Custom Formatters](#creating-custom-formatters)
- [Formatter Inheritance](#formatter-inheritance)


## Overview


Firmo provides the following coverage report formatters:
| Formatter     | Description                                                           | Primary Use Case                             |
|---------------|-----------------------------------------------------------------------|---------------------------------------------|
| HTML          | Rich, interactive HTML report with syntax highlighting                | Human readability, detailed analysis         |
| JSON          | Machine-readable JSON report                                         | Integration with other tools, data processing |
| LCOV          | LCOV format for integration with lcov tools                           | Integration with standard coverage tools     |
| Cobertura     | XML-based Cobertura format                                            | CI/CD integration, standard reporting        |
| Summary       | Plain text summary of coverage statistics                             | Command-line output, basic overview          |
| JUnit         | XML format compatible with JUnit-style test reports                   | CI/CD integration, test reporting            |
| TAP           | Test Anything Protocol format                                         | Integration with TAP consumers               |
| CSV           | Comma-separated values format                                         | Data export, spreadsheet import              |

## Formatter Architecture


Firmo uses a class-based architecture for all formatters:


- All formatters extend a base `Formatter` class
- Each formatter implements specific methods for its format
- Formatters use inheritance for shared functionality
- Configuration is centralized but can be overridden per formatter
- Formatters provide both validation and formatting capabilities


### Formatter Inheritance Hierarchy



```text
Formatter (Base Class)
├── HTMLFormatter
├── JSONFormatter
├── LCOVFormatter
├── CoberturaFormatter
├── SummaryFormatter
├── JUnitFormatter
├── TAPFormatter
└── CSVFormatter
```



## Base Formatter Configuration


All formatters inherit these common configuration options from the base formatter:
| Option                  | Type    | Default         | Description                                        |
|-------------------------|---------|----------------|----------------------------------------------------|
| `output_path`           | string  | `nil`          | Path where the report should be saved             |
| `validate`              | boolean | `true`         | Validate data before formatting                    |
| `normalize_data`        | boolean | `true`         | Normalize data structure before formatting        |
| `validate_output`       | boolean | `false`        | Validate formatted output                         |
| `verbose`               | boolean | `false`        | Enable verbose logging                            |
| `strict_mode`           | boolean | `false`        | Strict mode for validations                       |

## Formatter Configuration


All formatters are configured through the central configuration system. Configuration options can be set through:


1. Command-line arguments with the `--format` flag
2. Configuration file (`.firmo-config.lua`)
3. Programmatic configuration via `central_config.set()`


### General Configuration



```lua
-- In .firmo-config.lua
return {
  reporting = {
    format = "html", -- Default formatter to use
    output_path = "coverage-reports/", -- Output directory for reports
    formatters = {
      -- Format-specific settings (see below)
    }
  }
}
```



## HTML Formatter


The HTML formatter generates a comprehensive, interactive HTML report with syntax highlighting, coverage statistics, and file navigation.

### Configuration Options



```lua
-- In .firmo-config.lua
return {
  reporting = {
    formatters = {
      html = {
        output_path = "coverage-reports/coverage-report.html", -- Custom output path
        show_line_numbers = true, -- Show line numbers
        syntax_highlighting = true, -- Enable syntax highlighting
        theme = "dark", -- Default color theme ("dark" or "light")
        max_lines_display = 200, -- Maximum lines to display per file
        simplified_large_files = true, -- Use simplified rendering for files > 1000 lines
      }
    }
  }
}
```



### Features



- Interactive file navigation
- Three-state coverage visualization (covered, executed, not covered)
- Syntax highlighting for Lua code
- Sort files by coverage percentage
- Toggle between dark and light themes
- Coverage statistics and summaries
- Line execution counts


## JSON Formatter


The JSON formatter outputs coverage data in a structured, machine-readable JSON format suitable for integration with other tools.

### Configuration Options



```lua
-- In .firmo-config.lua
return {
  reporting = {
    formatters = {
      json = {
        output_path = "coverage-reports/coverage-report.json", -- Custom output path
        pretty = true, -- Format JSON with indentation
        truncate_content = true, -- Truncate large line content for smaller files
        content_limit = 50, -- Limit characters per line content (if truncating)
      }
    }
  }
}
```



### JSON Output Structure



```json
{
  "summary": {
    "total_files": 10,
    "total_lines": 1200,
    "executable_lines": 800,
    "executed_lines": 650,
    "covered_lines": 600,
    "line_coverage_percent": 75,
    "function_coverage_percent": 80
  },
  "files": {
    "lib/module.lua": {
      "path": "lib/module.lua",
      "name": "module.lua",
      "total_lines": 120,
      "executable_lines": 80,
      "executed_lines": 65,
      "covered_lines": 60,
      "line_coverage_percent": 75,
      "lines": {
        /* Line-specific data */
      },
      "functions": {
        /* Function-specific data */
      }
    }
    /* Additional files */
  }
}
```



## LCOV Formatter


The LCOV formatter generates reports in the LCOV format, which is compatible with standard coverage tools like `genhtml` and integrates with many CI systems.

### Configuration Options



```lua
-- In .firmo-config.lua
return {
  reporting = {
    formatters = {
      lcov = {
        output_path = "coverage-reports/coverage-report.lcov", -- Custom output path
      }
    }
  }
}
```



### LCOV Output Example



```text
TN:lib/module.lua
SF:lib/module.lua
FN:10,function_name
FNDA:5,function_name
FNF:1
FNH:1
DA:10,5
DA:11,5
DA:12,5
LF:3
LH:3
end_of_record
```



## Cobertura Formatter


The Cobertura formatter produces XML reports in the Cobertura format, which is widely supported by CI/CD systems and coverage visualization tools.

### Configuration Options



```lua
-- In .firmo-config.lua
return {
  reporting = {
    formatters = {
      cobertura = {
        output_path = "coverage-reports/coverage-report.cobertura", -- Custom output path
      }
    }
  }
}
```



### Cobertura Output Example



```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-04.dtd">
<coverage line-rate="0.75" branch-rate="0" lines-covered="600" lines-valid="800" branches-covered="0" branches-valid="0" complexity="0" version="0.1" timestamp="2025-03-27T10:15:00">
  <sources>
    <source>.</source>
  </sources>
  <packages>
    <!-- Package data -->
  </packages>
</coverage>
```



## Summary Formatter


The Summary formatter outputs a plain text summary of coverage statistics, ideal for command-line output and basic reporting.

### Configuration Options



```lua
-- In .firmo-config.lua
return {
  reporting = {
    formatters = {
      summary = {
        output_path = "coverage-reports/coverage-summary.txt", -- Custom output path
        show_files = true, -- List individual files in summary
        sort_by = "coverage", -- Sort files by coverage percentage
      }
    }
  }
}
```



## JUnit Formatter


The JUnit formatter generates XML reports compatible with JUnit test reporting tools and CI systems.

### Configuration Options



```lua
-- In .firmo-config.lua
return {
  reporting = {
    formatters = {
      junit = {
        output_path = "coverage-reports/junit-results.xml", -- Custom output path
      }
    }
  }
}
```



## TAP Formatter


The TAP (Test Anything Protocol) formatter generates output compatible with TAP consumers, useful for integration with other testing frameworks.

### Configuration Options



```lua
-- In .firmo-config.lua
return {
  reporting = {
    formatters = {
      tap = {
        output_path = "coverage-reports/tap-results.tap", -- Custom output path
      }
    }
  }
}
```



## CSV Formatter


The CSV formatter generates comma-separated values files for easy import into spreadsheets and data analysis tools.

### Configuration Options



```lua
-- In .firmo-config.lua
return {
  reporting = {
    formatters = {
      csv = {
        output_path = "coverage-reports/coverage-data.csv", -- Custom output path
        include_lines = false, -- Don't include line-level data
        delimiter = ",", -- CSV delimiter character
      }
    }
  }
}
```



## Multiple Formatters


You can generate multiple report formats simultaneously using the command line or configuration:


```bash

# Generate both HTML and LCOV reports


lua firmo.lua --coverage --format=html,lcov tests/
```



```lua
-- In .firmo-config.lua
return {
  reporting = {
    format = {"html", "lcov", "json"}, -- Generate all three formats
    output_path = "coverage-reports/", -- Base directory for all reports
    formatters = {
      html = {
        output_path = "coverage-reports/index.html",
      },
      lcov = {
        output_path = "coverage-reports/lcov.info",
      },
      json = {
        output_path = "coverage-reports/coverage.json",
      }
    }
  }
}
```



## Creating Custom Formatters


You can create custom formatters by extending the base Formatter class:


```lua
local Formatter = require('lib.reporting.formatters.base')
local error_handler = require('lib.tools.error_handler')
-- Create a custom formatter by extending the base formatter
local CustomFormatter = Formatter.extend("custom", "cst")
-- Set version
CustomFormatter._VERSION = "1.0.0"
-- Implement the format method (required)
function CustomFormatter:format(coverage_data, options)
  -- Normalize data for consistent structure
  local data = self:normalize_coverage_data(coverage_data)

  -- Format data according to your needs
  local output = "# Custom Coverage Report\n\n"
  output = output .. "Total files: " .. data.summary.total_files .. "\n"
  output = output .. "Coverage: " .. string.format("%.2f%%", data.summary.coverage_percent) .. "\n"

  -- Return formatted string
  return output
end
-- Register the formatter
function CustomFormatter.register(formatters)
  -- Create an instance of the formatter
  local formatter = CustomFormatter.new()

  -- Register with the formatters registry
  formatters.coverage = formatters.coverage or {}
  formatters.coverage.custom = function(data, options)
    return formatter:format(data, options)
  end

  return true
end
return CustomFormatter
```


To use your custom formatter:


```lua
local reporting = require('lib.reporting')
local custom_formatter = require('path.to.custom_formatter')
-- Register the custom formatter
reporting.register_formatter(custom_formatter)
-- Use the custom formatter
local report = reporting.format_coverage(coverage_data, "custom")
reporting.write_file("./reports/custom-report.cst", report)
```



## Formatter Inheritance


You can extend existing formatters to customize their behavior:


```lua
local JSONFormatter = require('lib.reporting.formatters.json')
local error_handler = require('lib.tools.error_handler')
-- Create extended JSON formatter
local EnhancedJSON = {}
setmetatable(EnhancedJSON, {__index = JSONFormatter})
-- Override the format method to customize output
function EnhancedJSON:format(coverage_data, options)
  -- Call the parent formatter's format method
  local json_data = JSONFormatter.format(self, coverage_data, options)

  -- Parse JSON to add custom fields
  local success, parsed = pcall(require('cjson').decode, json_data)
  if success then
    -- Add custom fields
    parsed.custom = {
      timestamp = os.time(),
      environment = os.getenv("ENV") or "development"
    }

    -- Convert back to JSON
    return require('cjson').encode(parsed)
  end

  -- Return original if parsing failed
  return json_data
end
-- Register the enhanced formatter
function EnhancedJSON.register(formatters)
  -- Create an instance
  local formatter = EnhancedJSON.new()

  -- Register with the formatters registry
  formatters.coverage = formatters.coverage or {}
  formatters.coverage.enhanced_json = function(data, options)
    return formatter:format(data, options)
  end

  return true
end
return EnhancedJSON
```



## Integrating with External Tools


### LCOV Integration


To use the LCOV output with the `genhtml` tool:


```bash

# Generate LCOV report


lua firmo.lua --coverage --format=lcov tests/

# Generate HTML from LCOV data


genhtml -o coverage-html coverage-reports/coverage-report-v2.lcov
```



### CI/CD Integration


For continuous integration, the Cobertura or JUnit formats are often most useful:


```bash

# Generate Cobertura report for CI


lua firmo.lua --coverage --format=cobertura tests/
```


Many CI systems like Jenkins, GitHub Actions, and GitLab CI can automatically interpret Cobertura XML reports to display coverage information.
