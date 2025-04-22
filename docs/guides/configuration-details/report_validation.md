# Report Validation Configuration


This document describes how to configure the report validation system in firmo. The report validation system ensures that coverage reports are accurate and consistent by validating data structure, performing statistical analysis, and cross-checking with static analysis.

## Configuration Options


The validation system can be configured both programmatically and through the configuration file. Here are the available options:

### Basic Options


| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `validate_reports` | boolean | `true` | Enables or disables report validation completely |
| `validate_line_counts` | boolean | `true` | Validates that line counts in summary match file-by-file counts |
| `validate_percentages` | boolean | `true` | Validates that coverage percentages are calculated correctly |
| `validate_file_paths` | boolean | `true` | Validates that file paths exist (when absolute paths are used) |
| `validate_function_counts` | boolean | `true` | Validates function count consistency |
| `validate_block_counts` | boolean | `true` | Validates block count consistency |
| `validate_cross_module` | boolean | `true` | Validates consistency between different data sections |
| `validation_threshold` | number | `0.5` | Tolerance threshold for percentage comparisons (in percentage points) |
| `warn_on_validation_failure` | boolean | `true` | Logs warnings when validation fails |

### Advanced Options


When using `auto_save_reports()` or saving reports through the reporting API, you can also use these additional options:
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `strict_validation` | boolean | `false` | If true, prevents saving reports that fail validation |
| `validation_report` | boolean | `false` | If true, generates a separate validation report |
| `validation_report_path` | string | nil | Custom path for the validation report |

## Configuration in .firmo-config.lua


You can configure the validation system in your `.firmo-config.lua` file:


```lua
return {
  -- ... other configuration sections

  reporting = {
    -- ... other reporting options

    validation = {
      validate_reports = true,
      validate_line_counts = true,
      validate_percentages = true,
      validate_file_paths = true,
      validate_function_counts = true,
      validate_block_counts = true,
      validate_cross_module = true,
      validation_threshold = 0.5,
      warn_on_validation_failure = true
    }
  }
}
```



## Using Validation Programmatically


You can validate coverage reports programmatically using the reporting module:


```lua
local reporting = require("lib.reporting")
-- Basic validation
local is_valid, issues = reporting.validate_coverage_data(coverage_data)
if not is_valid then
  print("Validation failed with " .. #issues .. " issues")
  for i, issue in ipairs(issues) do
    print(issue.category .. ": " .. issue.message)
  end
end
-- Comprehensive validation with statistics and cross-check
local result = reporting.validate_report(coverage_data)
if not result.validation.is_valid then
  print("Validation failed")
else
  print("Validation passed")

  -- Show statistical outliers
  if #result.statistics.outliers > 0 then
    print("Found " .. #result.statistics.outliers .. " statistical outliers")
  end

  -- Show anomalies
  if #result.statistics.anomalies > 0 then
    print("Found " .. #result.statistics.anomalies .. " anomalies")
  end
end
```



## Saving Reports with Validation


When saving reports, you can control validation behavior:


```lua
local reporting = require("lib.reporting")
-- Save with default validation (enabled)
reporting.save_coverage_report("coverage.html", coverage_data, "html")
-- Save with explicit validation options
reporting.save_coverage_report("coverage.html", coverage_data, "html", {
  validate = true,
  strict_validation = true  -- Fail if validation doesn't pass
})
-- Auto-save reports with validation
reporting.auto_save_reports(coverage_data, nil, nil, {
  report_dir = "./reports",
  validate = true,
  strict_validation = false,
  validation_report = true,
  validation_report_path = "./reports/validation.json"
})
```



## Validation Report Format


When generating a validation report (by setting `validation_report = true`), the report contains comprehensive validation data in JSON format:


```json
{
  "validation": {
    "is_valid": true,
    "issues": []
  },
  "statistics": {
    "median_line_coverage": 75.5,
    "mean_line_coverage": 80.2,
    "std_dev_line_coverage": 12.3,
    "outliers": [
      {
        "file": "/path/to/outlier.lua",
        "coverage": 20.5,
        "z_score": 4.8
      }
    ],
    "anomalies": [
      {
        "file": "/path/to/anomaly.lua",
        "reason": "Large file with low coverage",
        "details": {
          "lines": 500,
          "coverage": 15.2
        }
      }
    ]
  },
  "cross_check": {
    "files_checked": 25,
    "discrepancies": {
      "/path/to/file.lua": [
        {
          "line": 42,
          "type": "executable_line",
          "static_analysis": true,
          "coverage_data": false
        }
      ]
    },
    "unanalyzed_files": [],
    "analysis_success": true
  }
}
```



## CI/CD Integration


For Continuous Integration environments, it's recommended to use strict validation to ensure accurate reports:


```lua
-- In .firmo-config.lua for CI environments
return {
  reporting = {
    validation = {
      validate_reports = true,
      strict_validation = true,  -- Fail CI if validation doesn't pass
      validation_report = true,  -- Generate a validation report
      validation_threshold = 0.1 -- Tighter tolerance for CI
    }
  }
}
```


When running in CI, you can specify strict validation on the command line:


```bash
lua test.lua --coverage --strict-validation tests/
```



## Common Validation Issues


Here are some common validation issues and how to resolve them:

### Line Count Discrepancies


If total line counts don't match, this could indicate:


- A problem with the coverage data collection
- Files being added or removed during the test run
- Issues with static analysis

Resolution: Ensure all tests are run with the same code state and no files are modified during the run.

### Percentage Calculation Errors


If percentages don't match calculations, this could indicate:


- Rounding errors in the calculation
- Inclusion of non-executable lines in the calculation
- Different weighting methods for the overall percentage

Resolution: Check the calculation method and ensure consistency.

### File Path Issues


If file paths are reported as missing, this could indicate:


- Absolute paths that don't match the current environment
- Files that were moved or deleted after the tests ran
- Path normalization issues between platforms

Resolution: Use relative paths or check path normalization.

### Cross-Module Inconsistencies


If there are inconsistencies between data sections, this could indicate:


- A bug in the coverage collection
- Data corruption during report generation
- Different files being included in different sections

Resolution: Check for bugs in the coverage module and ensure consistent file inclusion.

## Next Steps


After configuring validation, consider using the following features:


- **HTML formatter** with enhanced visualizations
- **Statistical analysis** to identify areas for testing improvement
- **Validation reports** for historical tracking of code quality

For more information, see the [Coverage Report Formatters](./formatters.md) and [Coverage Guide](../coverage.md) documentation.
