# Reporting Module Knowledge

## Purpose

This document outlines key internal concepts, architecture, and implementation patterns for the `lib/reporting` module, intended for developers working on or extending Firmo's reporting system.

## Key Concepts

-   **`init.lua` Role:** The main `lib/reporting/init.lua` module serves as the public interface and orchestrator. It manages:
    -   **Configuration:** Loading defaults, merging with `central_config` via `configure`.
    -   **Formatter Registry Access:** Provides `get_formatter(format, type)` to retrieve registered formatter functions.
    -   **Formatting Orchestration:** Provides `format_coverage`, `format_quality`, `format_results` which find the appropriate formatter and execute its `format` method.
    -   **File Saving:** Includes `write_file` (which handles JSON encoding and directory creation) and `auto_save_reports` for convenience.
-   **Formatter Registry (`M._formatters`):** An internal table within `init.lua` that maps report types (`coverage`, `quality`, `results`) to format names (e.g., `html`, `json`) and their corresponding formatter functions.
-   **Formatter Loading (`formatters/init.lua`):** This module automatically requires all `.lua` files in the `formatters/` directory and calls their exported `register(registry)` function to populate the `M._formatters` registry in the main `init.lua`.
-   **Formatter Structure:** Formatters are class-based, inheriting from `lib/reporting/formatters/base.lua`. See [`lib/reporting/formatters/knowledge.md`](formatters/knowledge.md) for details on creating formatters.
-   **Data Flow:**
    1.  External code (e.g., runner, user script) obtains data (coverage, quality, results).
    2.  Calls `reporting.format_<type>(data, format, options)` or `reporting.auto_save_reports(...)`.
    3.  `reporting.init.lua` uses `get_formatter` to find the registered function for the requested format and type.
    4.  The registered function (which typically calls `formatter_instance:format(data, options)`) is executed.
    5.  The `format` method (potentially normalizing data first) generates the report content (string or table).
    6.  The content is returned to the caller or written to a file via `write_file`.
-   **Error Handling:** Functions generally return `result, error_object` using the `error_handler` module for consistency. File operations use `safe_io_operation`.

## Usage Examples / Patterns

### Generating and Saving Reports

```lua
--[[
  Demonstrates the standard workflow for generating and saving reports
  using the main reporting module API.
]]
local reporting = require("lib.reporting")
local coverage = require("lib.coverage") -- For data source example
local fs = require("lib.tools.filesystem") -- For utility example

-- Assuming coverage_data exists (e.g., from coverage.get_data())
if coverage_data then
  -- Generate HTML Coverage Report content
  local html_content, err = reporting.format_coverage(coverage_data, "html", { theme = "dark" })

  if html_content then
    -- Save the content to a file
    local success, write_err = reporting.write_file("./reports/coverage.html", html_content)
    if not success then
      print("Failed to write HTML report:", write_err and write_err.message or "Unknown")
    end
  else
    print("HTML Report Formatting Error:", err and err.message or "Unknown")
  end

  -- Generate JUnit Test Results Report content (assuming results_data exists)
  if results_data then
     local junit_content, err2 = reporting.format_results(results_data, "junit")
     if junit_content then
        reporting.write_file("./reports/results.xml", junit_content)
     else
       print("JUnit Report Error:", err2 and err2.message or "Unknown")
     end
  end

  -- Use Auto-Save for multiple formats easily
  -- Creates files like ./auto-reports/coverage-report.html, ./auto-reports/coverage-report.lcov, etc.
  local save_results = reporting.auto_save_reports(coverage_data, quality_data, results_data, {
    report_dir = "./auto-reports",
    -- Specify which formats to generate for each type
    formats = {
        coverage = {"html", "lcov"},
        quality = {"summary", "json"},
        results = {"junit"}
    }
  })
  -- save_results table contains success/error status for each generated file
end
```

### Custom Formatters (Overview)

```lua
--[[
  Brief overview of custom formatter integration.
  See lib/reporting/formatters/knowledge.md for implementation details.
]]

-- 1. Create your formatter module (e.g., my_formatter.lua) inheriting from base.lua
--    and implement the :format() method.

-- 2. Implement the register function in your module:
--    function MyFormatter.register(formatters_registry)
--      local instance = MyFormatter.new()
--      formatters_registry.coverage = formatters_registry.coverage or {}
--      formatters_registry.coverage.myformat = function(d, o) return instance:format(d, o) end
--      return true
--    end

-- 3. Ensure formatters/init.lua requires your module.

-- 4. Use the formatter via the reporting module:
local report_content = reporting.format_coverage(coverage_data, "myformat")
if report_content then
  reporting.write_file("report.myext", report_content)
end
```

### Error Handling

The primary reporting functions (`format_*`, `write_file`, `auto_save_reports`) return `result, error_object`. Always check the first return value for `nil` or `false` to detect errors.

```lua
local reporting = require("lib.reporting")
local error_handler = require("lib.core.error_handler")

-- Example: Handling errors from format_coverage
local html_content, err = reporting.format_coverage(coverage_data, "non_existent_format")

if not html_content then
  print("Error generating report:")
  print(error_handler.format_error(err)) -- Use format_error for details
  -- Handle error (e.g., skip saving, log warning)
else
  -- Proceed with saving
  reporting.write_file("report.html", html_content)
end
```

## Related Components / Modules

-   **Source:** [`lib/reporting/init.lua`](init.lua)
-   **Formatters:** [`lib/reporting/formatters/`](formatters/) (Includes `base.lua`, `init.lua`, and specific formatters)
-   **Formatter Knowledge:** [`lib/reporting/formatters/knowledge.md`](formatters/knowledge.md) (Details on implementing formatters)
-   **Usage Guide:** [`docs/guides/reporting.md`](../../../docs/guides/reporting.md)
-   **API Reference:** [`docs/api/reporting.md`](../../../docs/api/reporting.md)
-   **Configuration:** [`lib/core/central_config.lua`](../../core/central_config.lua)
-   **Error Handling:** [`lib/core/error_handler/init.lua`](../../core/error_handler/init.lua)
-   **Filesystem:** [`lib/tools/filesystem/init.lua`](../../tools/filesystem/init.lua) (Used by `write_file`)
-   **JSON:** [`lib/tools/json/init.lua`](../../tools/json/init.lua) (Used by `write_file` and JSON formatter)
