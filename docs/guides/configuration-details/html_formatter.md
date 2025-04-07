# HTML Formatter Configuration

This document describes how to configure the HTML formatter in firmo. The HTML formatter generates visually rich coverage reports with syntax highlighting, code state visualization, execution counts, and block coverage indicators.

## Configuration Options

The HTML formatter can be configured both programmatically and through the configuration file. Here are the available options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `theme` | string | `"dark"` | Visual theme for the report. Options: `"dark"`, `"light"` |
| `show_line_numbers` | boolean | `true` | Whether to display line numbers in the code view |
| `collapsible_sections` | boolean | `true` | Makes file sections collapsible for easier navigation |
| `highlight_syntax` | boolean | `true` | Enables syntax highlighting for code |
| `asset_base_path` | string | `nil` | Base path for assets (CSS, JS); useful when hosted on a subdirectory |
| `include_legend` | boolean | `true` | Whether to include the coverage legend in the report |
| `display_execution_counts` | boolean | `true` | Show execution counts on hover |
| `max_execution_count` | number | `nil` | If set, caps displayed execution counts at this value |
| `display_block_coverage` | boolean | `true` | Highlights code blocks (functions, if statements, loops) |
| `enhance_tooltips` | boolean | `true` | Shows detailed information in tooltips |

## Configuration in .firmo-config.lua

You can configure the HTML formatter in your `.firmo-config.lua` file:

```lua
return {
  reporting = {
    formatters = {
      html = {
        theme = "dark",
        show_line_numbers = true,
        collapsible_sections = true,
        highlight_syntax = true,
        asset_base_path = nil,
        include_legend = true,
        display_execution_counts = true,
        display_block_coverage = true,
        enhance_tooltips = true
      }
    }
  }
}
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

## Theme Configuration

The HTML formatter supports both light and dark themes. The theme affects the color scheme of the entire report.

### Dark Theme (Default)

The dark theme uses a dark background with high-contrast colors for coverage states:

- Dark green for covered lines
- Amber for executed-but-not-covered lines
- Dark red for uncovered lines
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