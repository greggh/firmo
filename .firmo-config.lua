-- firmo custom configuration
-- Specific configuration for the firmo project itself

return {
  -- Coverage Configuration
  coverage = {
    enabled = false, -- Only enable with --coverage flag
    debug = false, -- Disable debug mode to avoid excessive logging

    -- Include/exclude function patterns
    include = function(path)
      -- Include all Lua files by default
      if path:match("%.lua$") then
        return true
      end
      return false
    end,

    exclude = function(path)
      -- Exclude test files to avoid inflating coverage numbers
      if path:match("tests/") or path:match("test%.lua$") then
        return true
      end
      return false
    end,
  },

  -- LuaCov debug hook options
  debug_hook = {
    track_lines = true, -- Track line execution
    track_calls = true, -- Track function calls
    coroutine_support = true, -- Support for coroutines
    save_stats = true, -- Automatically save stats on completion
  },
  -- Report settings
  report = {
    format = "html", -- Default report format
    dir = "./coverage-reports", -- Report output directory
    title = "Firmo Coverage Report", -- Report title
    colors = {
      covered = "#00FF00", -- Green for covered lines
      executed = "#FFA500", -- Orange for executed lines
      not_covered = "#FF0000", -- Red for not covered lines
    },
    show_file_navigator = true, -- Show file navigation
    include_line_content = true, -- Include line content in reports
    show_execution_count = true, -- Show execution count heatmap
  },

  -- Validation settings
  validation = {
    threshold = 80, -- Standard coverage threshold
    validate_reports = true, -- Validate report data
  },

  -- Reporting configuration
  reporting = {
    validation = {
      validate_reports = true, -- Enable basic validations
      validate_percentages = true, -- Keep percentage validations
      validate_file_paths = true, -- Validate file paths
      validation_threshold = 1.0, -- 1% tolerance for percentage mismatches
    },

    -- HTML formatter configuration
    formatters = {
      html = {
        -- Visual settings
        theme = "dark", -- Use dark theme for reports
        show_file_navigator = true, -- Show file navigation panel
        collapsible_sections = true, -- Make report sections collapsible

        -- Processing for debug hook coverage system
        force_three_state_visualization = true, -- Use three-state visualization

        -- Enhanced features
        enhanced_navigation = true, -- Enable enhanced navigation
        show_execution_heatmap = true, -- Show execution count heatmap
      },
    },
  },

  -- Test runner settings for our project
  runner = {
    test_pattern = "*_test.lua", -- Our test file naming convention
    report_dir = "./reports", -- Where to save reports
    show_timing = true, -- Show execution times
    parallel = false, -- Disable parallel during development
  },

  -- Logging Configuration - useful for debugging
  logging = {
    level = 3, -- INFO level for better performance
    timestamps = true, -- Include timestamps
    use_colors = true, -- Use colors for better readability

    -- Module-specific log levels
    modules = {
      coverage = 2, -- WARN level for coverage module to reduce logging
      runner = 3, -- INFO level for runner
    },
  },

  -- Debug Configuration
  debug = {
    ast_output = true, -- Enable AST structure debugging
    source_mapping = true, -- Show source mapping information
    generated_code = true, -- Show generated code during transformation
  },
}
