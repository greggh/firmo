# Quality Configuration Reference


This document provides detailed configuration options for Firmo's quality validation system. Use these options to customize quality validation according to your project's needs.

## Central Configuration Schema


The quality module is configured through the central configuration system, which can be set in `.firmo-config.lua` or programmatically through the `central_config` module.

### Core Quality Options



```lua
-- In .firmo-config.lua
return {
  quality = {
    -- Basic settings
    enabled = true,                -- Whether quality validation is enabled
    level = 3,                     -- Required quality level (1-5)
    strict = false,                -- Strict mode (fail on first issue)

    -- Custom rules (optional)
    custom_rules = {
      require_describe_block = true,
      min_assertions_per_test = 3
    },

    -- Integration options
    coverage_data = nil,           -- Will be populated by runner with coverage module instance
  }
}
```


| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | `false` | Enable quality validation |
| `level` | number | `1` | Quality level to enforce (1-5) |
| `strict` | boolean | `false` | Fail on first quality issue |
| `custom_rules` | table | `{}` | Custom quality validation rules |
| `coverage_data` | table | `nil` | Reference to coverage module (set automatically) |

### Integration with Reporting Configuration



```lua
-- In .firmo-config.lua
return {
  quality = {
    -- Quality settings as above
  },

  reporting = {
    -- Quality report format settings
    formats = {
      quality = {
        default = "html"           -- Default format for quality reports
      }
    },

    -- Quality report path templates
    templates = {
      quality = "./reports/quality-{timestamp}.{format}"
    },

    -- Formatter-specific options
    formatters = {
      html = {
        theme = "dark",
        show_line_numbers = true,
        highlight_syntax = true
      },
      json = {
        pretty = true,
        indent = 2
      }
    }
  }
}
```



### Coverage Integration Settings


The quality module integrates with the coverage module to validate test coverage thresholds:


```lua
-- In .firmo-config.lua
return {
  quality = {
    enabled = true,
    level = 5  -- Level 5 requires 90% coverage threshold
  },

  coverage = {
    enabled = true,
    threshold = 90  -- This threshold will be checked by quality validation
  }
}
```



## Detailed Level Requirements


The quality module defines five progressive quality levels, each with specific requirements:

### Level 1: Basic



```lua
{
  min_assertions_per_test = 1,
  assertion_types_required = {"equality", "truth"},
  assertion_types_required_count = 1,
  test_organization = {
    require_describe_block = true,
    require_it_block = true,
    max_assertions_per_test = 15,
    require_test_name = true
  },
  required_patterns = {},
  forbidden_patterns = {"SKIP", "TODO", "FIXME"},
}
```



### Level 2: Standard



```lua
{
  min_assertions_per_test = 2,
  assertion_types_required = {"equality", "truth", "type_checking"},
  assertion_types_required_count = 2,
  test_organization = {
    require_describe_block = true,
    require_it_block = true,
    max_assertions_per_test = 10,
    require_test_name = true,
    require_before_after = false
  },
  required_patterns = {"should"},
  forbidden_patterns = {"SKIP", "TODO", "FIXME"},
}
```



### Level 3: Comprehensive



```lua
{
  min_assertions_per_test = 3,
  assertion_types_required = {"equality", "truth", "type_checking", "error_handling", "edge_cases"},
  assertion_types_required_count = 3,
  test_organization = {
    require_describe_block = true,
    require_it_block = true,
    max_assertions_per_test = 8,
    require_test_name = true,
    require_before_after = true,
    require_context_nesting = true
  },
  required_patterns = {"should", "when"},
  forbidden_patterns = {"SKIP", "TODO", "FIXME"},
}
```



### Level 4: Advanced



```lua
{
  min_assertions_per_test = 4,
  assertion_types_required = {"equality", "truth", "type_checking", "error_handling", "mock_verification", "edge_cases", "boundary"},
  assertion_types_required_count = 4,
  test_organization = {
    require_describe_block = true,
    require_it_block = true,
    max_assertions_per_test = 6,
    require_test_name = true,
    require_before_after = true,
    require_context_nesting = true,
    require_mock_verification = true
  },
  required_patterns = {"should", "when", "boundary"},
  forbidden_patterns = {"SKIP", "TODO", "FIXME"},
}
```



### Level 5: Complete



```lua
{
  min_assertions_per_test = 5,
  assertion_types_required = {"equality", "truth", "type_checking", "error_handling", "mock_verification", "edge_cases", "boundary", "performance", "security"},
  assertion_types_required_count = 5,
  test_organization = {
    require_describe_block = true,
    require_it_block = true,
    max_assertions_per_test = 5,
    require_test_name = true,
    require_before_after = true,
    require_context_nesting = true,
    require_mock_verification = true,
    require_coverage_threshold = 90, -- 90% coverage requirement
    require_performance_tests = true,
    require_security_tests = true
  },
  required_patterns = {"should", "when", "boundary", "security", "performance"},
  forbidden_patterns = {"SKIP", "TODO", "FIXME"},
}
```



## Assertion Type Requirements


The quality module can recognize and validate the following assertion types:
| Assertion Type | Example Patterns | Description |
|----------------|------------------|-------------|
| `equality` | `expect().to.equal()`, `assert.equals()`, `==` | Equality comparisons |
| `truth` | `expect().to.be.truthy()`, `assert.is_true()` | Truth value assertions |
| `type_checking` | `expect().to.be.a()`, `assert.is_string()` | Type checking |
| `error_handling` | `expect().to.fail()`, `assert.error()` | Error validation |
| `mock_verification` | `expect().to.have.been.called()`, `assert.spy()` | Mock verification |
| `edge_cases` | Tests with `nil`, `empty`, bounds | Edge case testing |
| `boundary` | Tests with `boundary`, `limit`, `edge` | Boundary condition testing |
| `performance` | `benchmark`, `timing`, `speed` | Performance validation |
| `security` | `security`, `injection`, `validation` | Security testing |

## Report Configuration


### Available Report Formats


The quality module supports multiple report formats through the reporting module:
| Format | Description | Extension |
|--------|-------------|-----------|
| `summary` | Text summary for console output | N/A |
| `html` | Interactive HTML report with color coding | `.html` |
| `json` | Structured JSON data for programmatic use | `.json` |

### Report Path Templates


Configure report paths using templates in the central configuration:


```lua
reporting = {
  templates = {
    quality = "./reports/quality-{timestamp}.{format}"
  }
}
```


Available template variables:


- `{timestamp}` - Current date/time (format configurable)
- `{format}` - Report format (html, json, etc.)
- `{date}` - Current date only


### Format-Specific Options


#### HTML Format Options



```lua
reporting = {
  formatters = {
    html = {
      theme = "dark",              -- "dark" or "light"
      show_line_numbers = true,    -- Show line numbers in code samples
      collapsible_sections = true, -- Allow sections to be collapsed
      highlight_syntax = true,     -- Syntax highlighting for code
      asset_base_path = nil,       -- Path to assets (CSS, JS)
      include_legend = true,       -- Include color coding legend
      enable_dark_mode = true,     -- Support dark mode toggle
      inline_source = true,        -- Include source code inline
    }
  }
}
```



#### JSON Format Options



```lua
reporting = {
  formatters = {
    json = {
      pretty = false,               -- Pretty-print JSON output
      schema_version = "1.0",       -- Schema version to include
      indentation = 2,              -- Indentation level when pretty-printing
      enable_streaming = true,      -- Enable streaming for large files
      chunk_size = 1024 * 1024,     -- 1MB chunks for streaming
      omit_source_code = false,     -- Whether to include source code
    }
  }
}
```



#### Summary Format Options



```lua
reporting = {
  formatters = {
    summary = {
      detailed = false,            -- Show detailed information
      show_files = true,           -- Show file list
      colorize = true,             -- Use ANSI colors in terminal output
      show_function_coverage = true, -- Show function coverage
      sort_by = "coverage",        -- Sort by coverage percentage
      max_files = 100,             -- Maximum files to show in summary
    }
  }
}
```



## Integration Configuration


### Coverage Integration


The quality module integration with the coverage system is configured automatically by the runner, but can be manually configured:


```lua
local quality = require("lib.quality")
local coverage = require("lib.coverage")
-- Initialize quality with coverage
quality.init({
  enabled = true,
  level = 5,  -- Level 5 requires coverage check
  coverage_data = coverage -- Pass the coverage module
})
-- Run tests
-- ...
-- Check if quality meets requirements including coverage
local meets, issues = quality.check_file("tests/my_test.lua", 5)
```



### Reporting Integration


Configure the quality module to use the reporting system:


```lua
local quality = require("lib.quality")
local reporting = require("lib.reporting")
-- Generate a quality report
local report_data = quality.get_report_data()
local html_report = reporting.format_quality(report_data, "html")
-- Save the report
reporting.save_quality_report("quality-report.html", report_data, "html")
-- Or use quality's direct methods which use reporting under the hood
quality.report("html")  -- Returns the formatted report
quality.save_report("quality-report.html", "html")  -- Saves the report to a file
```



### Test Runner Integration


The quality module is integrated with the test runner by default:


```bash

# Run tests with quality validation


lua test.lua --quality --quality-level=3 tests/

# Run with quality and generate reports


lua test.lua --quality --quality-level=3 --report-dir=./reports tests/

# Run with both quality and coverage


lua test.lua --quality --coverage tests/
```


Or programmatically:


```lua
local runner = require("lib.core.runner")
local result = runner.run_all("tests/", {
  quality = true,
  quality_level = 3,
  coverage = true,
  report_dir = "./reports"
})
if not result then
  print("Tests or quality validation failed")
  os.exit(1)
end
```



## Examples


### Complete Configuration with All Options



```lua
-- In .firmo-config.lua
return {
  quality = {
    enabled = true,
    level = 3,
    strict = false,
    custom_rules = {
      require_describe_block = true,
      min_assertions_per_test = 3
    }
  },

  reporting = {
    formats = {
      quality = {
        default = "html"
      }
    },
    templates = {
      quality = "./reports/quality-{timestamp}.{format}"
    },
    formatters = {
      html = {
        theme = "dark",
        show_line_numbers = true,
        highlight_syntax = true
      },
      json = {
        pretty = true
      },
      summary = {
        detailed = true,
        colorize = true
      }
    }
  },

  coverage = {
    enabled = true,
    threshold = 90
  }
}
```



### Direct Configuration in Code



```lua
-- file: tests/setup.lua
local quality = require("lib.quality")
local central_config = require("lib.core.central_config")
local coverage = require("lib.coverage")
-- Configure quality module
quality.init({
  enabled = true,
  level = 4,
  strict = false,
  coverage_data = coverage
})
-- Configure via central_config
central_config.set("reporting.formats.quality.default", "html")
central_config.set("reporting.templates.quality", "./reports/quality-{timestamp}.{format}")
-- Configure reporting formatters
central_config.set("reporting.formatters.html", {
  theme = "dark",
  show_line_numbers = true,
  highlight_syntax = true
})
-- Run tests with quality validation
-- (usually done by the test runner, shown here for completeness)
local meet_quality = quality.check_file("tests/my_test.lua", 4)
if not meet_quality then
  print("Test file does not meet quality level 4 requirements")
end
-- Generate and save quality report
local success, err = quality.save_report("quality-report.html", "html")
if not success then
  print("Failed to save quality report: " .. err)
end
```



# Quality Validation Configuration


This document describes the comprehensive configuration options for the firmo quality validation system, which ensures tests meet required standards for reliability, completeness, and maintainability.

## Overview


The quality module provides a powerful system for validating test quality with support for:


- Multiple quality levels with progressive requirements
- Assertion type tracking and verification
- Test structure validation
- Required and forbidden patterns
- Organization and naming standards
- Integration with the central configuration system
- Customizable quality requirements


## Configuration Options


### Core Options


| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | `false` | Enable quality validation during test runs. |
| `level` | number | `1` | Quality level to enforce (1-5, from basic to complete). |
| `strict` | boolean | `false` | Enforce quality requirements strictly (fail tests that don't meet quality standards). |

### Quality Level Requirements


Each quality level has specific requirements that tests must meet:

#### Level 1 (Basic)



```lua
{
  min_assertions_per_test = 1,
  assertion_types_required = {"equality", "truth"},
  assertion_types_required_count = 1,
  require_test_name = true,
  max_assertions_per_test = 15
}
```



#### Level 2 (Standard)



```lua
{
  min_assertions_per_test = 2,
  assertion_types_required = {"equality", "truth", "type_checking"},
  assertion_types_required_count = 2,
  require_test_name = true,
  max_assertions_per_test = 10,
  require_before_after = false
}
```



#### Level 3 (Comprehensive)



```lua
{
  min_assertions_per_test = 3,
  assertion_types_required = {"equality", "truth", "type_checking", "error_handling", "edge_cases"},
  assertion_types_required_count = 3,
  require_test_name = true,
  max_assertions_per_test = 8,
  require_before_after = true
}
```



#### Level 4 (Advanced)



```lua
{
  min_assertions_per_test = 4,
  assertion_types_required = {"equality", "truth", "type_checking", "error_handling", "edge_cases", "deep_equality"},
  assertion_types_required_count = 4,
  require_test_name = true,
  max_assertions_per_test = 6,
  require_before_after = true,
  require_context_nesting = true
}
```



#### Level 5 (Complete)



```lua
{
  min_assertions_per_test = 5,
  assertion_types_required = {"equality", "truth", "type_checking", "error_handling", "edge_cases", "deep_equality", "performance"},
  assertion_types_required_count = 5,
  require_test_name = true,
  max_assertions_per_test = 5,
  require_before_after = true,
  require_context_nesting = true,
  require_security_tests = true
}
```



## Configuration in .firmo-config.lua


You can configure the quality validation system in your `.firmo-config.lua` file:


```lua
return {
  -- Quality validation configuration
  quality = {
    -- Core settings
    enabled = true,              -- Enable quality validation
    level = 3,                   -- Set quality level to "comprehensive"
    strict = false,              -- Don't fail tests that don't meet quality standards

    -- Custom rules (optional)
    custom_rules = {
      require_documentation = true,
      min_coverage = 85,
      require_snapshot_tests = false
    }
  }
}
```



## Programmatic Configuration


You can also configure the quality module programmatically:


```lua
local quality = require("lib.quality")
-- Basic configuration
quality.init({
  enabled = true,
  level = 2,
  strict = false
})
-- Set specific quality level
quality.set_level(3)
-- Get current quality level
local level = quality.get_level()
local level_name = quality.level_name(level)
print("Current quality level:", level, "(", level_name, ")")
```



## Assertion Types


The quality module tracks and validates various assertion types:


```lua
-- Core assertion types
local assertion_types = {
  equality = {"equal", "same", "not_equal", "not_same"},
  truth = {"true", "false", "truthy", "falsy", "nil", "not_nil"},
  type_checking = {"type", "instance", "match", "not_match", "contains"},
  error_handling = {"error", "no_error", "throws", "not_throws"},
  edge_cases = {"empty", "not_empty", "length", "above", "below", "between"},
  deep_equality = {"deep_equal", "table_match", "property", "keys", "values"},
  performance = {"benchmark", "performance", "timing", "memory"},
  security = {"sanitize", "validate", "escape", "injection"}
}
```



## Quality Reports


The quality module can generate various report formats:


```lua
-- Generate a quality report
local report = quality.report("text")  -- "text", "json", or "html"
-- Generate summary report
local summary = quality.summary_report()
-- Save report to file
local success, err = quality.save_report("quality-report.html", "html")
```



## Integration with Test Runner


The quality module integrates with Firmo's test runner:


```lua
-- In test runner
local quality = require("lib.quality")
-- Enable quality validation
quality.init({
  enabled = true,
  level = 3,
  strict = true
})
-- At test start
quality.start_test(test_name)
-- Track assertion
quality.track_assertion("equality")
-- At test end
quality.end_test()
-- Check if quality requirements are met
if not quality.is_quality_passing() then
  print("Tests do not meet quality level", quality.get_level())

  -- Generate quality report
  local report = quality.report()
  print(report)
end
```



## Custom Quality Rules


You can define custom quality rules:


```lua
-- Add custom quality requirement
quality.add_custom_requirement(
  "test_documentation", 
  function(test_data)
    -- Check if all tests have documentation
    return test_data.documentation_percentage or 0
  },
  90  -- Require 90% of tests to have documentation
)
-- In .firmo-config.lua
return {
  quality = {
    enabled = true,
    level = 3,
    custom_rules = {
      test_documentation = {
        enabled = true,
        minimum = 90
      },
      coverage_percentage = {
        enabled = true,
        minimum = 85
      }
    }
  }
}
```



## Quality Template Generation


The quality module can generate template test files that meet quality requirements:


```lua
-- Generate a template test file for level 3
local template, err = quality.create_test_file(3, "tests/my_module_test.lua")
-- Analyze a directory for quality compliance
local results, err = quality.analyze_directory("tests/", true)  -- true = recursive
```



## Best Practices


### Setting the Right Quality Level



```lua
-- For a new project, start with level 1
quality.set_level(1)
-- For established projects, use level 2-3
quality.set_level(3)
-- For mission-critical code, use level 4-5
quality.set_level(5)
```



### Progressive Quality Implementation



```lua
-- Start with non-strict mode
quality.init({
  enabled = true,
  level = 1,
  strict = false  -- Report issues but don't fail tests
})
-- Later, enable strict mode after fixing issues
quality.init({
  enabled = true,
  level = 2,
  strict = true  -- Now fail tests that don't meet quality standards
})
-- Gradually increase levels as test quality improves
quality.set_level(3)
```



### Focus on Specific Assertion Types



```lua
-- Check which assertion types are being used
local report = quality.report()
print("Assertion types used:", report.assertions.types)
-- Identify missing assertion types
for _, required_type in ipairs(quality.levels[3].requirements.assertion_types_required) do
  if not report.assertions.types[required_type] then
    print("Missing assertion type:", required_type)
  end
end
```



## Troubleshooting


### Common Issues



1. **Tests failing quality validation**: 
   - Lower the quality level temporarily while improving tests
   - Set `strict = false` to see quality issues without failing tests
   - Generate a quality report to identify specific problems
2. **Missing assertion types**:
   - Check which assertion types are required for your quality level
   - Add missing assertion types to tests
   - Use quality templates as examples
3. **Too many assertions per test**:
   - Break large tests into smaller, focused tests
   - Use `describe` and nested `it` blocks for better organization
   - Keep each test focused on a single behavior
4. **Quality reports showing low scores**:
   - Focus on improving one quality level at a time
   - Address test organization issues first
   - Add missing assertion types
   - Improve test naming and structure


## Example Configuration Files


### Development Configuration



```lua
-- .firmo-config.development.lua
return {
  quality = {
    enabled = true,
    level = 2,           -- Standard quality level
    strict = false,      -- Don't fail tests yet
    custom_rules = {
      coverage_percentage = {
        enabled = true,
        minimum = 70     -- Lower coverage threshold for development
      }
    }
  }
}
```



### CI Configuration



```lua
-- .firmo-config.ci.lua
return {
  quality = {
    enabled = true,
    level = 3,           -- Comprehensive quality level
    strict = true,       -- Fail tests that don't meet standards
    custom_rules = {
      coverage_percentage = {
        enabled = true,
        minimum = 85     -- Higher coverage threshold for CI
      }
    }
  }
}
```



### Production Configuration



```lua
-- .firmo-config.production.lua
return {
  quality = {
    enabled = true,
    level = 4,           -- Advanced quality level for production code
    strict = true,       -- Fail tests that don't meet standards
    custom_rules = {
      coverage_percentage = {
        enabled = true,
        minimum = 90     -- High coverage threshold for production
      },
      security_tests_required = true  -- Require security tests for production
    }
  }
}
```


These configuration options give you complete control over test quality validation, allowing you to enforce standards appropriate for your project's maturity level and requirements.
