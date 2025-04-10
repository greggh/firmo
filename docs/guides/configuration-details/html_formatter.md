# HTML Coverage Formatter

The HTML formatter generates interactive, visual coverage reports using a class-based architecture. It provides detailed line-by-line coverage information with syntax highlighting, file navigation, summary statistics, and theme support.
## Class Usage

The HTML formatter can be used directly as a class for more control:

```lua
local HTMLFormatter = require('lib.reporting.formatters.html')

-- Create a formatter instance with options
local formatter = HTMLFormatter.new({
  theme = "dark",
  show_line_numbers = true,
  syntax_highlighting = true
})

-- Generate a report in one step
local success, result = formatter:generate(
  coverage_data,
  "coverage/index.html"
)

if success then
  print("Report generated at: " .. result)
else
  print("Failed to generate report: " .. result.message)
end
```

## Configuration

The HTML formatter can be customized through the `.firmo-config.lua` file:

```lua
-- In .firmo-config.lua
return {
  reporting = {
    formatters = {
      html = {
        -- Output path for the HTML report
        output_path = "coverage/index.html",
        
        -- Visual customization
        theme = "dark",              -- "dark" or "light"
        show_line_numbers = true,    -- Show line numbers in source code
        syntax_highlighting = true,  -- Enable syntax highlighting (can impact performance)
        
        -- Performance options
        simplified_large_files = true,  -- Use simplified view for large files (>1000 lines)
        max_lines_display = 200,        -- Maximum lines to display per file
        simplified_rendering = false,    -- Force simplified rendering for all files
        
        -- Content customization
        show_execution_counts = true,   -- Show execution counts for each line
        show_uncovered_files = true,    -- Include files with 0% coverage
        show_full_path = true,          -- Show full file paths (vs. short names)
        sort_files_by = "coverage",     -- "coverage", "name", or "path"
        
        -- Custom titles and metadata
        title = "Coverage Report",      -- Report title
        project_name = null,            -- Optional project name
        include_timestamp = true,       -- Include generation timestamp
        
        -- Advanced options
        custom_css = null,              -- Path to custom CSS file to include
        custom_js = null,               -- Path to custom JavaScript file to include
        inline_assets = true            -- Embed all CSS/JS in HTML
      }
    }
  }
}
```
```

## Using HTML Formatter Programmatically

You can configure the HTML formatter programmatically using the reporting module:

```lua
local reporting = require("lib.reporting")

-- Configure the HTML formatter
reporting.configure_formatter("html", {
  theme = "light",
  show_line_numbers = true,
  collapsible_sections = true
})

-- Generate a report with the configured formatter
local html_report = reporting.format_coverage(coverage_data, "html")

-- Save the report to a file
reporting.write_file("coverage.html", html_report)
```

## Understanding HTML Coverage Visualization

The HTML formatter visualizes coverage data with several visual indicators:

### Line Coverage States

The formatter distinguishes between four line states:

1. **Covered** (Green): Lines that were executed and properly tested
2. **Executed but not covered** (Amber/Orange): Lines that were executed during runtime but not validated by assertions
3. **Not executed** (Red): Executable code that never ran
4. **Non-executable** (Gray): Comments, blank lines, and structural code (like "end" statements)

### Block Coverage

Code blocks (functions, if statements, loops) are indicated with colored borders:

- **Green borders**: Blocks that executed at least once
- **Red borders**: Blocks that never executed

### Execution Counts

When hovering over lines, you can see:

- How many times the line executed
- For blocks, how many times the block executed
- For conditions, whether they evaluated as true, false, or both

## Configuration Options Reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `output_path` | string | `"coverage-report.html"` | Path where the HTML report will be saved |
| `theme` | string | `"dark"` | Color theme: "dark" or "light" |
| `show_line_numbers` | boolean | `true` | Display line numbers in source code |
| `syntax_highlighting` | boolean | `true` | Enable syntax highlighting for source code |
| `simplified_large_files` | boolean | `true` | Use simplified view for files over 1000 lines |
| `max_lines_display` | number | `200` | Maximum number of lines to display per file |
| `simplified_rendering` | boolean | `false` | Use simplified rendering for all files |
| `show_execution_counts` | boolean | `true` | Show execution counts for each line |
| `show_uncovered_files` | boolean | `true` | Include files with 0% coverage |
| `show_full_path` | boolean | `true` | Show full file paths instead of just file names |
| `sort_files_by` | string | `"coverage"` | How to sort files: "coverage", "name", or "path" |
| `title` | string | `"Coverage Report"` | Report title displayed in the header |
| `project_name` | string | `null` | Optional project name displayed in the header |
| `include_timestamp` | boolean | `true` | Include generation timestamp in the report |
| `custom_css` | string | `null` | Path to custom CSS file to include |
| `custom_js` | string | `null` | Path to custom JavaScript file to include |
| `inline_assets` | boolean | `true` | Embed all CSS/JS in the HTML file |

## Theme System

The HTML formatter features a built-in theme system with light and dark themes. The theme can be selected in three ways:

1. Configuration option `theme` (default is "dark")
2. User preference toggle in the UI (persisted in localStorage)
3. System preference via `prefers-color-scheme` media query

### Dark Theme

The dark theme uses a dark background with light text and is optimized for low-light environments.

```
Background: #1a1a1a
Text: #e0e0e0
Card Background: #242424
Covered Lines: rgba(76, 175, 80, 0.4)
Executed Lines: rgba(255, 152, 0, 0.4)
Not Covered Lines: rgba(244, 67, 54, 0.4)
```

### Light Theme

The light theme uses a light background with dark text, optimized for readability and printing.

```
Background: #f5f5f5
Text: #333
Card Background: #fff
Covered Lines: rgba(76, 175, 80, 0.3)
Executed Lines: rgba(255, 152, 0, 0.3)
Not Covered Lines: rgba(244, 67, 54, 0.3)
```
- Dark gray for non-executable lines

### Light Theme

The light theme uses a light background with softer colors:

- Light green for covered lines
- Light amber for executed-but-not-covered lines
- Light red for uncovered lines
- Light gray for non-executable lines

## Example: Dark vs Light Theme

To see the differences between themes, you can generate both:

```lua
-- Generate dark theme report
reporting.configure_formatter("html", {theme = "dark"})
reporting.save_coverage_report("coverage-dark.html", coverage_data, "html")

-- Generate light theme report
reporting.configure_formatter("html", {theme = "light"})
reporting.save_coverage_report("coverage-light.html", coverage_data, "html")
```

## Example: Configure from Command Line

You can also configure the HTML formatter from the command line:

```bash
lua run_tests.lua --coverage --html.theme=light --html.show_line_numbers=true
```

## Report Legend

The HTML formatter includes a comprehensive legend explaining all coverage states and visual indicators. The legend includes:

- Line coverage states (covered, executed-not-covered, not executed, non-executable)
- Block coverage indicators (executed, not executed)
- Condition coverage states (true only, false only, both, none)
- Tooltip explanations

You can disable the legend by setting `include_legend = false` if you prefer a more compact report.

## Asset Base Path

If you're hosting the HTML report on a subdirectory of a website, you may need to set the `asset_base_path` to ensure CSS and JavaScript assets load correctly:

```lua
reporting.configure_formatter("html", {
  asset_base_path = "/coverage-reports/"
})
```

This is useful for CI/CD environments where reports are published to specific paths.

## Adjusting Display for Large Codebases

For large codebases, you might want to optimize the HTML formatter:

```lua
reporting.configure_formatter("html", {
  collapsible_sections = true,  -- Makes navigation easier
  display_block_coverage = false,  -- Reduces visual complexity
  enhance_tooltips = true  -- Keeps detailed information available on demand
})
```

## Integration with Report Validation

For the best results, combine HTML formatting with report validation:

```lua
-- In .firmo-config.lua
return {
  reporting = {
    formatters = {
      html = {
        theme = "dark",
        display_execution_counts = true
      }
    },
    validation = {
      validate_reports = true,
      validation_report = true
    }
  }
}
```

This ensures your HTML reports display accurate information and any issues are documented in a validation report.

## Custom Styling

The HTML formatter uses CSS variables for styling, allowing for customization by modifying the report after generation:

1. Generate the HTML report
2. Open it in a text editor
3. Modify the CSS variables in the `<style>` section
4. Save and view the customized report

## Browser Compatibility

The HTML report uses standard features and should work in all modern browsers:

- Chrome/Edge (Chromium-based)
- Firefox
- Safari

For older browsers, consider disabling some features:

```lua
reporting.configure_formatter("html", {
  highlight_syntax = false,  -- Simplifies the DOM
  collapsible_sections = false  -- Reduces JavaScript requirements
})
```

## Performance Considerations

For extremely large coverage reports (thousands of files), consider:

1. Splitting coverage reports by module or package
2. Using the JSON formatter for data analysis and HTML for visual inspection
3. Disabling syntax highlighting for better performance

## Next Steps

After configuring the HTML formatter, consider:

- Setting up [Report Validation](./report_validation.md) to ensure accuracy
- Configuring [Coverage Settings](../coverage.md) for better analysis 
- Using the JSON formatter for machine-readable data