# Reporting Formatters Knowledge

## Purpose

This document outlines key internal concepts, implementation patterns, and design considerations for the reporting formatter system within `lib/reporting/formatters/`. It's intended for developers creating new formatters or modifying existing ones.

## Key Concepts

-   **Base `Formatter` Class (`base.lua`):** All formatters inherit from this base class using `Formatter.extend(name, extension)`. It provides common structure and helper methods (`normalize_coverage_data`, `deep_copy`, `get_table_keys`).
-   **Class Structure:** Each formatter is typically implemented as a class inheriting from `Formatter`. It must define at least a `format(self, data, options)` method.
    -   `Formatter.extend(name, extension)`: Creates a new formatter class table with the specified `name` (e.g., "html") and default file `extension` (e.g., ".html"). It sets up the metatable for inheritance from the base `Formatter`.
    -   `MyFormatter.new(options)`: The constructor for formatter instances, usually created automatically by the `extend` setup. It takes formatter-specific `options`.
-   **Mandatory Method: `format(self, data, options)`:** This method receives the raw data (e.g., coverage data) and formatter-specific options. It should process the data (potentially using normalization helpers) and return the formatted report content (typically a string, or a table for JSON). On failure, it must return `nil, error_object`.
-   **Optional Method: `validate(self, data)`:** Can be implemented to validate the input data structure before formatting. Should return `true` or `false, error_object`. The base implementation performs basic checks.
-   **Helper Methods:** The base class provides helpers like `normalize_coverage_data` (ensures standard structure for coverage reports) which can be called via `self:normalize_coverage_data(data)`.
-   **Registration (`formatter_module.register(registry)`):** Each formatter module file (e.g., `html.lua`) **must** export a `register(formatters_registry)` function. This function is called by `lib/reporting/formatters/init.lua`. Inside `register`, the formatter creates an instance of itself (`MyFormatter.new()`) and assigns its `format` method (wrapped in a closure if needed) to the correct category (`coverage`, `quality`, `results`) and name (`myformat`) within the passed `formatters_registry` table. It should return `true` on successful registration.
-   **Initialization (`formatters/init.lua`):** This module automatically requires all built-in formatter modules in the same directory and calls their `register` function to populate the main formatter registry used by `lib/reporting/init.lua`.

## Usage Examples / Patterns

### Creating a Custom Formatter

```lua
-- lib/reporting/formatters/my_formatter.lua
local Formatter = require('lib.reporting.formatters.base')
local error_handler = require('lib.core.error_handler') -- Correct path

-- 1. Extend the base Formatter class
local MyFormatter = Formatter.extend("myformat", "myext")
MyFormatter._VERSION = "1.0.0"

-- 2. Implement the required format method
function MyFormatter:format(data, options)
  local output_string = ""
  -- Use self:normalize_coverage_data(data) if it's a coverage formatter
  -- Example: Simple text output for coverage
  if data and data.summary then
    local normalized_data = self:normalize_coverage_data(data) -- Normalize first
    output_string = "-- My Custom Report --\n"
    output_string = output_string .. "Total Files: " .. (normalized_data.summary.total_files or 0) .. "\n"
    output_string = output_string .. "Coverage: " .. string.format("%.2f%%", normalized_data.summary.coverage_percent or 0) .. "\n"
  else
    -- Handle other data types or return error if format is unsupported
    return nil, error_handler.validation_error("Unsupported data type for myformat", { data_type = type(data) })
  end

  return output_string -- Return the formatted string
end

-- 3. Implement the register function (called by formatters/init.lua)
function MyFormatter.register(formatters_registry)
  local formatter_instance = MyFormatter.new()
  -- Register for relevant report types (e.g., coverage)
  formatters_registry.coverage = formatters_registry.coverage or {}
  -- The key here ("myformat") must match the name passed to extend
  formatters_registry.coverage.myformat = function(data, opts)
    return formatter_instance:format(data, opts)
  end
  return true -- Indicate successful registration
end

return MyFormatter -- Return the formatter class table
```

### Using a Formatter (via Reporting Module)

Formatters are typically invoked through the main `reporting` module, which handles registry lookup, data fetching, and file writing.

```lua
-- Using a formatter (typically via reporting module)
local reporting = require("lib.reporting")
local coverage = require("lib.coverage") -- Assuming coverage data source

-- Assuming 'myformat' was registered for coverage
local coverage_data = coverage.get_data()
if coverage_data then
  local report_content, err = reporting.format_coverage(coverage_data, "myformat")
  if report_content then
    reporting.write_file("report.myext", report_content)
  else
    print("Error generating report:", err and err.message or "Unknown")
  end
end
```

### Error Handling within Formatters

The `format` method should return `nil, error_object` on failure. Use `error_handler` for consistency.

```lua
function MyFormatter:format(data, options)
  -- Validate input specific to this formatter
  if not data or not data.expected_field then
     return nil, error_handler.validation_error("Missing expected_field in data", { formatter = self.name })
  end

  -- Use try for complex operations
  local success, result_string, err = error_handler.try(function()
     local output = "-- Report --\n"
     -- ... complex formatting that might error ...
     if some_error_condition then error("Specific formatting error") end
     output = output .. "Data: " .. data.expected_field .. "\n"
     return output
  end)

  if not success then
     -- Wrap the original error if needed
     return nil, error_handler.runtime_error("MyFormat failed during generation", { formatter = self.name }, result_string)
  end

  return result_string
end
```

## Related Components / Modules

-   **Base Class:** [`lib/reporting/formatters/base.lua`](base.lua) - The foundation for all formatters.
-   **Registry Initializer:** [`lib/reporting/formatters/init.lua`](init.lua) - Loads and registers built-in formatters.
-   **Example Formatters:** [`html.lua`](html.lua), [`json.lua`](json.lua), [`lcov.lua`](lcov.lua), etc. - Reference implementations.
-   **Reporting Module:** [`lib/reporting/init.lua`](../init.lua) - The main module that uses the registered formatters.
-   **Reporting Guide:** [`docs/guides/reporting.md`](../../../../docs/guides/reporting.md)
-   **Reporting API:** [`docs/api/reporting.md`](../../../../docs/api/reporting.md)
-   **Error Handling:** [`lib/core/error_handler/init.lua`](../../../core/error_handler/init.lua) - Used for consistent error reporting.
