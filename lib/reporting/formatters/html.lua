--- HTML Report Formatter for Coverage and Quality
---
--- Generates interactive HTML reports for both code coverage results and
--- test quality analysis.
---
--- **Coverage Reports**: Include summary statistics, file lists, and
--- syntax-highlighted source code views with line coverage indicators.
--- Features theme toggling (light/dark) and performance optimizations for large files.
---
--- **Quality Reports**: Provide an overview of test quality, achieved levels,
--- statistics, and a list of issues. For common issues, interactive "Show Example"
--- buttons allow users to view suggested code snippets for fixes. The report also
--- features theme toggling (light/dark), a responsive pie chart for summary
--- statistics, and basic syntax highlighting for Lua code examples.
---
--- @module lib.reporting.formatters.html
--- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 2.0.0

--- @class CoverageReportFileStats Detailed coverage statistics for a single file.
--- @field name string Normalized path of the file.
--- @field path string Same as name (for compatibility/convenience).
--- @field lines table<number|string, CoverageLineEntry> Map of line number (string or number) to line data.
--- @field total_lines number Total number of lines in the file.
--- @field covered_lines number Number of lines with at least one hit.
--- @field executable_lines number Number of lines considered executable code.
--- @field functions table Placeholder for function coverage data.
--- @field executed_functions number Count of functions executed.
--- @field total_functions number Total count of functions defined.
--- @field line_coverage_percent number Percentage of lines covered (covered / executable).
--- @field function_coverage_percent number Percentage of functions covered (executed / total).
--- @field source? string Optional source code content.
--- @field simplified_rendering? boolean Internal flag indicating only summary should be shown for this file due to size.

--- @class CoverageLineEntry Detailed data for a single line.
--- @field executable boolean Whether the line is executable.
--- @field execution_count number Number of times the line was hit.
--- @field covered boolean Whether the line was covered (usually `execution_count > 0`).
--- @field content? string Optional source code content for the line.
--- @field line_type? string Optional classification (e.g., "comment", "blank").

--- @class CoverageReportSummary Overall coverage statistics for the report.
--- @field total_files number Total number of files analyzed.
--- @field covered_files number Number of files with at least one covered line.
--- @field total_lines number Total number of lines across all analyzed files.
--- @field covered_lines number Total number of lines covered across all analyzed files.
--- @field executable_lines number Total executable lines across all files.
--- @field total_functions number Total number of functions across all files.
--- @field executed_functions number Total number of functions executed across all files.
--- @field line_coverage_percent number Overall line coverage percentage.
--- @field function_coverage_percent number Overall function coverage percentage.
--- @field file_coverage_percent? number Percentage of files covered (if total_files > 0).

--- @class CoverageReportData Expected structure for coverage data input.
--- @field summary CoverageReportSummary Overall summary statistics.
--- @field files table<string, CoverageReportFileStats> Map of normalized filename to file statistics.
--- @field executed_lines? number Deprecated: Use `summary.executable_lines`.
--- @field covered_lines? number Deprecated: Use `summary.covered_lines`.

---@class HTMLFormatter API for generating HTML coverage reports.
---@field _VERSION string Module version.
---@field format_coverage fun(coverage_data: CoverageReportData): string Formats coverage data into a complete HTML document string.
---@field generate fun(coverage_data: CoverageReportData, output_path: string): boolean, table? Generates and writes the HTML report to a file. Returns `success, error`. @throws table If validation or file operations fail critically.
local M = {}

-- Lazy-load dependencies to avoid circular dependencies
---@diagnostic disable-next-line: unused-local
local _error_handler, _logging, _fs

-- Local helper for safe requires without dependency on error_handler
local function try_require(module_name)
  local success, result = pcall(require, module_name)
  if not success then
    print("Warning: Failed to load module:", module_name, "Error:", result)
    return nil
  end
  return result
end

--- Get the filesystem module with lazy loading to avoid circular dependencies
---@return table|nil The filesystem module or nil if not available
local function get_fs()
  if not _fs then
    _fs = try_require("lib.tools.filesystem")
  end
  return _fs
end

--- Get the success handler module with lazy loading to avoid circular dependencies
---@return table|nil The error handler module or nil if not available
local function get_error_handler()
  if not _error_handler then
    _error_handler = try_require("lib.tools.error_handler")
  end
  return _error_handler
end

--- Get the logging module with lazy loading to avoid circular dependencies
---@return table|nil The logging module or nil if not available
local function get_logging()
  if not _logging then
    _logging = try_require("lib.tools.logging")
  end
  return _logging
end

local quality_module = try_require("lib.quality") -- For get_level_name

--- Get a logger instance for this module
---@return table A logger instance (either real or stub)
local function get_logger()
  local logging = get_logging()
  if logging then
    return logging.get_logger("Reporting:HTMLFormatter")
  end
  -- Return a stub logger if logging module isn't available
  return {
    error = function(msg)
      print("[ERROR] " .. msg)
    end,
    warn = function(msg)
      print("[WARN] " .. msg)
    end,
    info = function(msg)
      print("[INFO] " .. msg)
    end,
    debug = function(msg)
      print("[DEBUG] " .. msg)
    end,
    trace = function(msg)
      print("[TRACE] " .. msg)
    end,
  }
end

-- Version
M._VERSION = "2.0.0"

local Formatter = try_require("lib.reporting.formatters.base") -- Required for .extend
local HTMLFormatter = Formatter.extend("html", "html")
HTMLFormatter._VERSION = M._VERSION -- Keep version consistent

---
--- Table mapping common quality issue message patterns to their corresponding
--- fix examples (title and code snippet) for display in HTML quality reports.
--- Each entry is a table with:
---   - `key_pattern` (string): Lua string pattern to match against an issue message.
---   - `title` (string): A concise title for the fix example.
---   - `snippet` (string): A Lua code string demonstrating a generic fix.
--- @type table<number, {key_pattern: string, title: string, snippet: string}>
--- @local
local ISSUE_FIX_EXAMPLES = {
  {
    key_pattern = "^Too few assertions: found (%d+), need at least (%d+)",
    title = "Add More Assertions",
    snippet = [[
-- Example: Ensure your test checks multiple aspects of the functionality.
it("should perform multiple checks on the result", function()
  local result = my_function_to_test() -- Assume this returns a table
  expect(result.value1).to.equal(expected_value1)
  expect(result.success_flag).to.be_truthy()
  -- Add more expect() calls to cover different properties or outcomes.
end)
]],
  },
  {
    key_pattern = "^Too many assertions: found (%d+), maximum is (%d+)",
    title = "Reduce Assertions per Test",
    snippet = [[
-- Example: Focus each test on a specific behavior or unit.
-- If a test becomes too long with too many assertions,
-- consider splitting it into multiple, more focused tests.

-- Instead of:
-- it("should handle all user profile operations", function()
--   -- ... many assertions for creation, update, deletion ...
-- end)

-- Consider:
it("should create a user profile successfully", function()
  -- ... assertions for creation ...
end)
it("should update an existing user profile", function()
  -- ... assertions for update ...
end)
]],
  },
  {
    key_pattern = "^Missing required assertion types: need (%d+) type%(s%), found (%d+). Missing: (.*)",
    title = "Diversify Assertion Types",
    snippet = [[
-- Example: Use a variety of assertions. If 'error_handling' is missing:
it("should handle invalid input gracefully", function()
  expect(function()
    process_data(nil) -- Function that should throw an error
  end).to.fail_with("Input data cannot be nil") -- or simply .to.fail()
end)

-- If 'type_checking' is missing for a function returning a table:
it("should return a correctly structured table", function()
  local data = get_user_details(1)
  expect(data).to.be.a("table")
  expect(data.id).to.be.a("number")
  expect(data.name).to.be.a("string")
end)
]],
  },
  {
    key_pattern = "^Missing describe block$",
    title = "Organize Tests with `describe`",
    snippet = [[
-- Example: Group related tests using describe blocks for better organization.
describe("User Authentication Module", function()
  it("should allow login with valid credentials", function()
    -- ... test logic and assertions ...
  end)

  it("should prevent login with invalid credentials", function()
    -- ... test logic and assertions ...
  end)
end)
]],
  },
  {
    key_pattern = "^Missing it block$",
    title = "Define Individual Tests with `it`",
    snippet = [[
-- Example: Each specific test case should be in an 'it' block.
describe("String Utilities", function()
  it("should concatenate two strings correctly", function()
    expect(string_util.concat("hello", "world")).to.equal("helloworld")
  end)
end)
]],
  },
  {
    key_pattern = "^Test doesn%.t have a proper descriptive name$",
    title = "Improve Test Name Clarity",
    snippet = [[
-- Example: Test names should clearly state what they are testing,
-- often using 'should' or 'when'.
-- BAD: it("test1", function() ... end)
-- GOOD: it("should return true when input is positive", function()
--   expect(my_check(10)).to.be_truthy()
-- end)
]],
  },
  {
    key_pattern = "^Missing setup/teardown with before/after blocks$",
    title = "Use `before` and `after` for Setup/Teardown",
    snippet = [[
-- Example: Use 'before' to set up common conditions or state for tests within a 'describe'
-- block, and 'after' to clean up any side effects after each test.
-- Firmo's 'before' and 'after' hooks run before and after each 'it' block within
-- their 'describe' scope, similar to 'beforeEach' and 'afterEach' in other frameworks.

describe("User Session Management", function()
  local user_session

  before(function()
    -- Setup: Simulate creating or loading a user session for each test.
    user_session = { user_id = 123, is_active = true, permissions = {"read"} }
    -- print("User session prepared for test.")
  end)

  after(function()
    -- Teardown: Simulate clearing or logging out the user session.
    user_session = nil
    -- print("User session cleaned up after test.")
  end)

  it("should allow access to resources if user has read permission", function()
    expect(user_session.is_active).to.be_truthy()
    local has_permission = false
    for _, p in ipairs(user_session.permissions) do
      if p == "read" then
        has_permission = true
        break
      end
    end
    expect(has_permission).to.be_truthy()
  end)

  it("should correctly reflect active status", function()
    expect(user_session.is_active).to.be_truthy()
    -- Potentially modify user_session here for this specific test if needed,
    -- 'after' hook will still reset it.
  end)
end)
]],
  },
  {
    key_pattern = "^Insufficient context nesting %(need at least 2 levels%)$",
    title = "Improve Test Organization with Nesting",
    snippet = [[
-- Example: Use nested describe blocks for complex features.
describe("Main Feature", function()
  describe("Sub-Feature A", function()
    it("should behave correctly under condition X", function()
      -- ...
    end)
  end)
  describe("Sub-Feature B", function()
    it("should handle scenario Y", function()
      -- ...
    end)
  end)
end)
]],
  },
  {
    key_pattern = "^Missing mock/spy verification$",
    title = "Verify Mock/Spy Interactions",
    snippet = [[
-- Example: Ensure your mocks/spies were called as expected.
local my_api = { get_data = function() end }
local firmo = require("firmo") -- Assuming firmo is available for spy
local spy_on_get_data = firmo.spy.on(my_api, "get_data")

-- my_service_that_uses_api(my_api) -- Function that calls my_api.get_data
-- For snippet, let's call it directly
my_api.get_data("some_arg")

expect(spy_on_get_data).to.have_been_called()
expect(spy_on_get_data).to.have_been_called_with("some_arg")

spy_on_get_data:restore()
]],
  },
  {
    key_pattern = "^Insufficient code coverage: (.*)%% %(threshold: (%d+)%%%)$",
    title = "Improve Code Coverage",
    snippet = [[
-- Example: To improve coverage, ensure your tests execute more paths
-- in the code under test.
-- Review the coverage report (e.g., HTML report) to see
-- which lines or branches are not being hit by your tests.

-- Consider:
-- - Testing different conditional branches (if/else statements).
-- - Testing error paths and exception handling.
-- - Testing loops with zero, one, and multiple iterations.
-- - Ensuring all functions/methods are called.
]],
  },
  {
    key_pattern = "^Missing required patterns: (.*)$",
    title = "Use Required Naming Patterns",
    snippet = [[
-- Example: If the pattern 'should' is required in test names:
-- BAD: it("validates input", function() ... end)
-- GOOD: it("should validate input correctly", function() ... end)

-- If 'when' is required for conditional scenarios:
-- BAD: it("admin access", function() ... end)
-- GOOD: it("should grant access when user is admin", function() ... end)
]],
  },
  {
    key_pattern = "^Found forbidden patterns: (.*)$",
    title = "Remove Forbidden Patterns",
    snippet = [[
-- Example: If 'TODO' or 'SKIP' in test names/descriptions are forbidden:
-- BAD: it.skip("should implement feature X -- TODO", function() ... end)
-- Remove '.skip' and the 'TODO' comment, or complete the test.

-- If certain assertion patterns are forbidden by a custom rule (less common),
-- refactor the test to use approved assertion methods.
]],
  },
}

-- Simple, self-contained CSS
local SIMPLE_CSS = [[
/* Theme Variables */
:root {
  /* Light Theme */
  --bg-color-light: #f5f5f5;
  --text-color-light: #333;
  --card-bg-light: #fff;
  --card-border-light: #e1e1e1;
  --header-bg-light: #fff;
  --header-border-light: #e1e1e1;
  --stat-box-bg-light: #f9f9f9;
  --stat-box-border-light: #e1e1e1;
  --muted-text-light: #666;
  --line-number-bg-light: #f9f9f9;
  --line-number-color-light: #999;
  --progress-bg-light: #e0e0e0;
  --hover-bg-light: #f9f9f9;
  --td-border-light: #e1e1e1;
  --target-highlight-light: #fffde7;

  /* Dark Theme */
  --bg-color-dark: #1a1a1a;
  --text-color-dark: #e0e0e0;
  --card-bg-dark: #242424;
  --card-border-dark: #3a3a3a;
  --header-bg-dark: #242424;
  --header-border-dark: #3a3a3a;
  --stat-box-bg-dark: #2a2a2a;
  --stat-box-border-dark: #3a3a3a;
  --muted-text-dark: #aaa;
  --line-number-bg-dark: #2a2a2a;
  --line-number-color-dark: #888;
  --progress-bg-dark: #3a3a3a;
  --hover-bg-dark: #2d2d2d;
  --td-border-dark: #3a3a3a;
  --target-highlight-dark: #3a3600;

  /* Shared Colors */
  --high-color: #4caf50;
  --medium-color: #ff9800;
  --low-color: #f44336;

  /* Coverage Status Colors - Higher contrast for better visibility */
  --covered-bg-dark: rgba(76, 175, 80, 0.4);     /* Green with more opacity */
  --executed-bg-dark: rgba(255, 152, 0, 0.4);    /* Orange with more opacity */
  --not-covered-bg-dark: rgba(244, 67, 54, 0.4); /* Red with more opacity */

  --covered-bg-light: rgba(76, 175, 80, 0.3);    /* Green for light theme */
  --executed-bg-light: rgba(255, 152, 0, 0.3);   /* Orange for light theme */
  --not-covered-bg-light: rgba(244, 67, 54, 0.3); /* Red for light theme */

  /* Dark Theme Syntax Highlighting */
  --keyword-dark: #ff79c6;
  --string-dark: #9ccc65;
  --comment-dark: #7e7e7e;
  --number-dark: #bd93f9;
  --function-dark: #8be9fd;

  /* Light Theme Syntax Highlighting */
  --keyword-light: #0033b3;
  --string-light: #067d17;
  --comment-light: #8c8c8c;
  --number-light: #1750eb;
  --function-light: #7c4dff;
}

/* Dark Mode by Default */
html {
  color-scheme: dark;
}

body {
  background-color: var(--bg-color-dark);
  color: var(--text-color-dark);
}

/* Basic reset */
html, body {
  margin: 0;
  padding: 0;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  font-size: 14px;
  line-height: 1.5;
}

/* Theme Toggle Switch */
.theme-switch-wrapper {
  display: flex;
  align-items: center;
  gap: 8px;
}

.theme-switch {
  position: relative;
  width: 40px;
  height: 20px;
}

.theme-switch input {
  opacity: 0;
  width: 0;
  height: 0;
}

.slider {
  position: absolute;
  cursor: pointer;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: #555;
  border-radius: 20px;
  transition: .4s;
}

.slider:before {
  position: absolute;
  content: "";
  height: 16px;
  width: 16px;
  left: 2px;
  bottom: 2px;
  background-color: white;
  border-radius: 50%;
  transition: .4s;
}

input:checked + .slider {
  background-color: #2196F3;
}

input:checked + .slider:before {
  transform: translateX(20px);
}

/* Layout */
.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 10px;
}

header {
  background-color: var(--header-bg-dark);
  border-bottom: 1px solid var(--header-border-dark);
  padding: 15px 0;
  margin-bottom: 20px;
}

h1, h2, h3, h4 {
  margin: 0 0 15px 0;
  font-weight: 600;
}

h1 { font-size: 24px; }
h2 { font-size: 20px; }
h3 { font-size: 16px; }
h4 { font-size: 14px; }

/* Coverage Summary */
.summary {
  background-color: var(--card-bg-dark);
  border: 1px solid var(--card-border-dark);
  border-radius: 4px;
  padding: 15px;
  margin-bottom: 20px;
}

.stats {
  display: flex;
  flex-wrap: wrap;
  gap: 20px;
  margin-bottom: 15px;
}

.stat-box {
  background-color: var(--stat-box-bg-dark);
  border: 1px solid var(--stat-box-border-dark);
  border-radius: 4px;
  padding: 10px;
  min-width: 150px;
}

.stat-label {
  font-size: 12px;
  color: var(--muted-text-dark);
}

.stat-value {
  font-size: 18px;
  font-weight: 600;
}

.high { color: var(--high-color); }
.medium { color: var(--medium-color); }
.low { color: var(--low-color); }

/* Progress bar */
.progress-bar {
  height: 8px;
  background-color: var(--progress-bg-dark);
  border-radius: 4px;
  overflow: hidden;
  margin-top: 3px;
}

.progress-value {
  height: 100%;
}

.progress-value.high { background-color: var(--high-color); }
.progress-value.medium { background-color: var(--medium-color); }
.progress-value.low { background-color: var(--low-color); }

/* File list */
.file-list {
  background-color: var(--card-bg-dark);
  border: 1px solid var(--card-border-dark);
  border-radius: 4px;
  margin-bottom: 20px;
}

.file-list-table {
  width: 100%;
  border-collapse: collapse;
}

.file-list-table th {
  text-align: left;
  padding: 10px;
  border-bottom: 1px solid var(--td-border-dark);
  background-color: var(--stat-box-bg-dark);
  font-weight: 600;
}

.file-list-table td {
  padding: 8px 10px;
  border-bottom: 1px solid var(--td-border-dark);
}

.file-list-table tr:hover {
  background-color: var(--hover-bg-dark);
}

/* Source code display */
.source-section {
  background-color: var(--card-bg-dark);
  border: 1px solid var(--card-border-dark);
  border-radius: 4px;
  margin-bottom: 20px;
}

/* Coverage status classes */
.covered {
  background-color: var(--covered-bg-dark);
}

.executed {
  background-color: var(--executed-bg-dark);
}

.not-covered {
  background-color: var(--not-covered-bg-dark);
}

.file-header {
  padding: 8px 10px;
  border-bottom: 1px solid var(--td-border-dark);
  background-color: var(--stat-box-bg-dark);
  font-weight: 600;
  font-size: 13px;
}

.file-header .file-path {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--text-color-dark); /* Use theme variable for dark mode */
}

.file-stats {
  padding: 5px 10px;
  border-bottom: 1px solid var(--td-border-dark);
  background-color: var(--stat-box-bg-dark);
  font-size: 12px;
  color: var(--text-color-dark); /* Use theme variable for dark mode */
  display: flex;
  justify-content: space-between;
}

/* Styling for the function details section with theme support */
.function-details-container {
  border-bottom: 1px solid var(--td-border-dark);
  background-color: var(--stat-box-bg-dark);
}

.function-details-container summary,
.function-details-container span,
.function-details-container th,
.function-details-container td,
.function-details-container a {
  color: var(--text-color-dark) !important; /* Light text for dark mode */
}

/* Make file headers and stats visible in dark mode */
.file-header,
.file-header *,
.file-stats,
.file-stats span:not(.high):not(.medium):not(.low),
.file-stats div {
  color: var(--text-color-dark) !important; /* Force text color in dark mode */
}

.source-code {
  overflow-x: auto;
}

.code-table {
  width: 100%;
  border-collapse: collapse;
  font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
  font-size: 12px;
  tab-size: 4;
}

/* Line styles */
.line-number {
  width: 40px;
  text-align: right;
  padding: 0 10px 0 10px;
  border-right: 1px solid var(--td-border-dark);
  user-select: none;
  color: var(--line-number-color-dark);
  background-color: var(--line-number-bg-dark);
}

.line-number a {
  color: var(--line-number-color-dark);
  text-decoration: none;
}

.exec-count {
  width: 30px;
  text-align: right;
  padding: 0 8px;
  border-right: 1px solid var(--td-border-dark);
  color: var(--muted-text-dark);
}

.code-content {
  padding: 0 5px 0 10px;
  white-space: pre;
}

.code-line {
  height: 18px;
  line-height: 18px;
}

.covered {
  background-color: rgba(76, 175, 80, 0.15);
}

.executed {
  background-color: rgba(255, 152, 0, 0.15);
}

.not-covered {
  background-color: rgba(244, 67, 54, 0.15);
}

.not-executable {
  color: var(--muted-text-dark);
}

/* Syntax highlighting for dark theme */
.keyword { color: var(--keyword-dark); font-weight: bold; }
.string { color: var(--string-dark); }
.comment { color: var(--comment-dark); font-style: italic; }
.number { color: var(--number-dark); }
.function { color: var(--function-dark); }

/* Footer */
footer {
  text-align: center;
  padding: 20px;
  color: var(--muted-text-dark);
  font-size: 12px;
}

/* Anchor link highlighting */
tr:target {
  background-color: var(--target-highlight-dark);
}

/* Light Theme Styles */
.light-theme {
  color-scheme: light;
  background-color: var(--bg-color-light);
  color: var(--text-color-light);
}

.light-theme header {
  background-color: var(--header-bg-light);
  border-bottom-color: var(--header-border-light);
}

.light-theme .summary,
.light-theme .file-list,
.light-theme .source-section {
  background-color: var(--card-bg-light);
  border-color: var(--card-border-light);
}

.light-theme .stat-box {
  background-color: var(--stat-box-bg-light);
  border-color: var(--stat-box-border-light);
}

.light-theme .stat-label,
.light-theme .exec-count,
.light-theme .not-executable,
.light-theme footer {
  color: var(--muted-text-light);
}

.light-theme .progress-bar {
  background-color: var(--progress-bg-light);
}

.light-theme .file-list-table th {
  background-color: var(--stat-box-bg-light);
  color: var(--text-color-light);
  border-color: var(--td-border-light);
}

.light-theme .file-header {
  background-color: var(--stat-box-bg-light);
  border-color: var(--td-border-light);
}

.light-theme .file-header,
.light-theme .file-header *,
.light-theme .file-stats,
.light-theme .file-stats span:not(.high):not(.medium):not(.low),
.light-theme .file-stats div {
  color: var(--text-color-light) !important; /* Force text color in light mode */
}

/* Light theme for function details */
.light-theme .function-details-container {
  border-bottom: 1px solid var(--td-border-light);
  background-color: var(--stat-box-bg-light);
}

.light-theme .function-details-container summary,
.light-theme .function-details-container span,
.light-theme .function-details-container th,
.light-theme .function-details-container td,
.light-theme .function-details-container a {
  color: var(--text-color-light) !important; /* Force dark text in light mode */
}

.light-theme .file-header {
  background-color: var(--stat-box-bg-light);
  border-color: var(--td-border-light);
}

.light-theme .file-stats {
  background-color: var(--stat-box-bg-light);
  border-color: var(--td-border-light);
}

.light-theme .file-list-table td {
  border-color: var(--td-border-light);
}

.light-theme .file-list-table tr:hover {
  background-color: var(--hover-bg-light);
}

.light-theme .line-number {
  background-color: var(--line-number-bg-light);
  color: var(--line-number-color-light);
  border-color: var(--td-border-light);
}

.light-theme .line-number a {
  color: var(--line-number-color-light);
}

.light-theme .exec-count {
  border-color: var(--td-border-light);
}

.light-theme tr:target {
  background-color: var(--target-highlight-light);
}

/* Light theme coverage status classes */
.light-theme .covered {
  background-color: var(--covered-bg-light);
}

.light-theme .executed {
  background-color: var(--executed-bg-light);
}

.light-theme .not-covered {
  background-color: var(--not-covered-bg-light);
}

/* Light theme syntax highlighting */
.light-theme .keyword { color: var(--keyword-light); font-weight: bold; }
.light-theme .string { color: var(--string-light); }
.light-theme .comment { color: var(--comment-light); font-style: italic; }
.light-theme .number { color: var(--number-light); }
.light-theme .function { color: var(--function-light); }
]]

--- Escapes HTML special characters.
---@param text_val string|number|boolean|nil The input value. Will be converted to string.
---@return string The escaped string.
---@private
local function escape_html(text_val)
  if text_val == nil then -- Explicitly handle nil to return empty string
    return ""
  end
  local text_str = tostring(text_val) -- Convert input to string
  return text_str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
end

--- Basic Lua syntax highlighter (currently simplified for performance).
--- Returns HTML-escaped code, with no actual syntax highlighting applied in this version.
---@param code string The Lua code string.
---@return string The HTML-escaped code (no highlighting applied currently).
---@private
local function highlight_lua(code)
  if not code then
    return ""
  end

  -- PERFORMANCE OPTIMIZATION: Just return escaped code without syntax highlighting
  -- This dramatically improves HTML generation performance
  return escape_html(code)

  -- The full syntax highlighting has been removed for performance reasons
  -- The current implementation was causing timeouts in test runs
end

--- Rounds a number to a specified number of decimal places.
---@param num number The number to round.
---@param decimal_places? number Number of decimal places (default 0).
---@return number The rounded number.
---@private
local function round(num, decimal_places)
  local mult = 10 ^ (decimal_places or 0)
  return math.floor(num * mult + 0.5) / mult
end

--- Gets CSS class ("high", "medium", "low") based on coverage percentage.
---@param percent number Coverage percentage (0-100).
---@return "high"|"medium"|"low" The CSS class name.
---@private
local function get_coverage_class(percent)
  if percent >= 80 then
    return "high"
  elseif percent >= 50 then
    return "medium"
  else
    return "low"
  end
end

--- Formats a percentage number as a string with "%", rounded to zero decimal places.
---@param percent number|nil The percentage (0-100). Handles nil input.
---@return string The formatted percentage string (e.g., "75%"). Returns "0%" for nil input.
---@private
local function format_percent(percent)
  if not percent or type(percent) ~= "number" then
    return "0%"
  end

  -- Round to nearest whole number
  percent = round(percent, 0)

  -- Return as string with % sign
  return tostring(percent) .. "%"
end

--- Generates the HTML markup for the coverage summary section.
--- Calculates overall percentages based on the data provided.
---@param coverage_data CoverageReportData The report data, requires `summary` and `files` fields.
---@return string The generated HTML string for the overview section.
---@private
local function generate_overview_html(coverage_data)
  -- Calculate summary statistics
  local total_files = 0
  local total_covered_lines = 0
  local total_executable_lines = 0
  local total_executed_functions = 0
  local total_functions = 0

  for _, file_data in pairs(coverage_data.files) do
    total_files = total_files + 1
    total_covered_lines = total_covered_lines + (file_data.covered_lines or 0)
    total_executable_lines = total_executable_lines + (file_data.executable_lines or 0)
    total_executed_functions = total_executed_functions + (file_data.executed_functions or 0)
    total_functions = total_functions + (file_data.total_functions or 0)
  end

  local line_coverage_percent = 0
  if total_executable_lines > 0 then
    line_coverage_percent = (total_covered_lines / total_executable_lines) * 100
  end

  local function_coverage_percent = 0
  if total_functions > 0 then
    function_coverage_percent = (total_executed_functions / total_functions) * 100
  end

  local line_class = get_coverage_class(line_coverage_percent)
  local function_class = get_coverage_class(function_coverage_percent)

  -- Create HTML
  local html = [[
  <div class="summary">
    <h2>Coverage Summary</h2>

    <div class="stats">
      <div class="stat-box">
        <div class="stat-label">Line Coverage</div>
        <div class="stat-value ]] .. line_class .. [[">]] .. format_percent(line_coverage_percent) .. [[</div>
        <div class="progress-bar">
          <div class="progress-value ]] .. line_class .. [[" style="width: ]] .. math.min(100, line_coverage_percent) .. [[%;"></div>
        </div>
        <div style="font-size: 12px; margin-top: 5px;">]] .. total_covered_lines .. [[ of ]] .. total_executable_lines .. [[ lines</div>
      </div>

      <div class="stat-box">
        <div class="stat-label">Function Coverage</div>
        <div class="stat-value ]] .. function_class .. [[">]] .. format_percent(function_coverage_percent) .. [[</div>
        <div class="progress-bar">
          <div class="progress-value ]] .. function_class .. [[" style="width: ]] .. math.min(
    100,
    function_coverage_percent
  ) .. [[%;"></div>
        </div>
        <div style="font-size: 12px; margin-top: 5px;">]] .. total_executed_functions .. [[ of ]] .. total_functions .. [[ functions</div>
      </div>

      <div class="stat-box">
        <div class="stat-label">Total Files</div>
        <div class="stat-value">]] .. total_files .. [[</div>
      </div>
    </div>
  </div>
  ]]

  return html
end

--- Generates the HTML markup for the file list table section.
--- Sorts files by path.
---@param coverage_data CoverageReportData The report data, requires `files` field.
---@return string The generated HTML string for the file list table.
---@private
local function generate_file_list_html(coverage_data)
  -- Prepare file list with sorted paths
  local file_paths = {}
  for path, _ in pairs(coverage_data.files) do
    table.insert(file_paths, path)
  end
  table.sort(file_paths)

  -- Start HTML
  local html = [[
  <div class="file-list">
    <h2 style="padding: 10px 15px; margin: 0; border-bottom: 1px solid #e1e1e1;">Files</h2>
    <table class="file-list-table">
      <thead>
        <tr>
          <th style="width: 60%;">Path</th>
          <th style="width: 15%;">Line Coverage</th>
          <th style="width: 15%;">Function Coverage</th>
          <th style="width: 10%;">Lines</th>
        </tr>
      </thead>
      <tbody>
  ]]

  -- Add each file
  for _, path in ipairs(file_paths) do
    local file_data = coverage_data.files[path]
    local file_id = path:gsub("[^%w]", "-")
    local line_coverage_percent = 0
    local function_coverage_percent = 0

    if file_data.executable_lines and file_data.executable_lines > 0 then
      line_coverage_percent = (file_data.covered_lines / file_data.executable_lines) * 100
    end

    if file_data.total_functions and file_data.total_functions > 0 then
      function_coverage_percent = (file_data.executed_functions / file_data.total_functions) * 100
    end

    local line_class = get_coverage_class(line_coverage_percent)
    local function_class = get_coverage_class(function_coverage_percent)

    html = html
      .. [[
      <tr>
        <td><a href="#file-]]
      .. file_id
      .. [[">]]
      .. path
      .. [[</a></td>
        <td>
          <div class="]]
      .. line_class
      .. [[">]]
      .. format_percent(line_coverage_percent)
      .. [[</div>
          <div class="progress-bar">
            <div class="progress-value ]]
      .. line_class
      .. [[" style="width: ]]
      .. math.min(100, line_coverage_percent)
      .. [[%;"></div>
          </div>
        </td>
        <td>
          <div class="]]
      .. function_class
      .. [[">]]
      .. format_percent(function_coverage_percent)
      .. [[</div>
          <div class="progress-bar">
            <div class="progress-value ]]
      .. function_class
      .. [[" style="width: ]]
      .. math.min(100, function_coverage_percent)
      .. [[%;"></div>
          </div>
        </td>
        <td>]]
      .. file_data.total_lines
      .. [[</td>
      </tr>
    ]]
  end

  -- Close HTML
  html = html .. [[
      </tbody>
    </table>
  </div>
  ]]

  return html
end

--- Generates the HTML markup for a single file's source code display section.
--- Includes line numbers, execution counts, coverage highlighting, and syntax highlighting (simplified).
--- Uses a simplified summary view if `file_data.simplified_rendering` is true.
--- Truncates display after `max_lines_to_display` for performance.
---@param file_data CoverageReportFileStats The data for the specific file.
---@param file_id string A unique HTML ID string generated from the file path.
---@return string The generated HTML string for the file section.
---@private
local function generate_file_source_html(file_data, file_id)
  -- Performance optimization based on file size characteristics
  if file_data.simplified_rendering then
    -- Generate summary view for large files to improve performance
    return [[
      <div id="file-]] .. file_id .. [[" class="source-section">
        <div class="file-header">
          <div class="file-path">]] .. file_data.path .. [[</div>
        </div>

        <div class="file-stats">
          <div>
            <span>Line Coverage: </span>
            <span class="]] .. get_coverage_class(file_data.line_coverage_percent) .. [[">]] .. format_percent(
      file_data.line_coverage_percent
    ) .. [[</span>
            <span>(]] .. file_data.covered_lines .. [[/]] .. file_data.executable_lines .. [[)</span>

            <span style="margin-left: 15px;">Function Coverage: </span>
            <span class="]] .. get_coverage_class(file_data.function_coverage_percent) .. [[">]] .. format_percent(
      file_data.function_coverage_percent
    ) .. [[</span>
            <span>(]] .. file_data.executed_functions .. [[/]] .. file_data.total_functions .. [[)</span>
          </div>
        </div>
        <div style="padding: 15px; text-align: center; font-style: italic;">
          <p><strong>Large file (]] .. file_data.total_lines .. [[ lines) - summary view shown for performance</strong></p>
          <p>Coverage: ]] .. file_data.covered_lines .. [[ covered of ]] .. file_data.executable_lines .. [[ executable lines</p>
        </div>
      </div>
    ]]
  end

  -- Get all line numbers and sort them
  local line_numbers = {}
  for line_num, _ in pairs(file_data.lines) do
    table.insert(line_numbers, line_num)
  end
  table.sort(line_numbers)

  -- Create HTML for file
  local html = [[
  <div class="source-section" id="file-]] .. file_id .. [[">
    <div class="file-header">
      <div class="file-path">]] .. file_data.path .. [[</div>
    </div>

    <div class="file-stats">
      <div>
        <span>Line Coverage: </span>
        <span class="]] .. get_coverage_class(file_data.line_coverage_percent) .. [[">]] .. format_percent(
    file_data.line_coverage_percent
  ) .. [[</span>
        <span>(]] .. file_data.covered_lines .. [[/]] .. file_data.executable_lines .. [[)</span>

        <span style="margin-left: 15px;">Function Coverage: </span>
        <span class="]] .. get_coverage_class(file_data.function_coverage_percent) .. [[">]] .. format_percent(
    file_data.function_coverage_percent
  ) .. [[</span>
        <span>(]] .. file_data.executed_functions .. [[/]] .. file_data.total_functions .. [[)</span>
      </div>
    </div>

    <div class="source-code">
      <table class="code-table">
        <tbody>
  ]]

  -- Performance optimization: limit number of displayed lines for all files
  local max_lines_to_display = 200
  local line_display_limit = math.min(#line_numbers, max_lines_to_display)

  for i = 1, line_display_limit do
    local line_num = line_numbers[i]
    local line_data = file_data.lines[line_num]
    local line_content = line_data.content or ""
    local line_class = ""
    local exec_count = ""

    if line_data.executable then
      exec_count = tostring(line_data.execution_count)
      if line_data.execution_count > 0 then
        -- Apply three-state visualization
        if line_data.covered then
          line_class = "covered" -- Green - tested and verified
        else
          line_class = "executed" -- Orange - executed but not verified
        end
      else
        line_class = "not-covered"
      end
    elseif line_data.line_type == "comment" or line_data.line_type == "blank" then
      line_class = "not-executable"
    end

    -- Create a table row with line number, execution count and code content
    html = html
      .. [[
          <tr id="L]]
      .. line_num
      .. [[" class="code-line ]]
      .. line_class
      .. [[">
            <td class="line-number">]]
      .. line_num
      .. [[</td>
            <td class="exec-count">]]
      .. exec_count
      .. [[</td>
            <td class="code-content">]]
      .. highlight_lua(line_content)
      .. [[</td>
          </tr>
    ]]
  end

  -- Add a note if we truncated the display
  if #line_numbers > max_lines_to_display then
    html = html
      .. [[
          <tr>
            <td colspan="3" style="padding: 10px; text-align: center; font-style: italic;">
              (File truncated to ]]
      .. max_lines_to_display
      .. [[ lines. ]]
      .. (#line_numbers - max_lines_to_display)
      .. [[ additional lines not shown for performance.)
            </td>
          </tr>
    ]]
  end

  -- Close HTML
  html = html .. [[
        </tbody>
      </table>
    </div>
  </div>
  ]]

  return html
end

--- Formats the coverage data into a complete HTML document string.
--- Combines overview, file list, and source code sections with CSS and JS.
---@param coverage_data CoverageReportData The report data structure. Assumes data is already normalized.
---@return string The complete HTML report content.
function M.format_coverage(coverage_data)
  -- Generate report sections
  local overview_html = generate_overview_html(coverage_data)
  local file_list_html = generate_file_list_html(coverage_data)

  -- Generate source code sections for each file, but skip large files
  local source_sections = ""
  for path, file_data in pairs(coverage_data.files) do
    -- Skip files over 1000 lines to prevent hanging
    if file_data.total_lines < 1000 then
      local file_id = path:gsub("[^%w]", "-")
      source_sections = source_sections .. generate_file_source_html(file_data, file_id)
    else
      -- Just add a placeholder for large files to avoid performance issues
      local file_id = path:gsub("[^%w]", "-")
      source_sections = source_sections
        .. [[
        <div id="file-]]
        .. file_id
        .. [[" class="file-section">
          <h2 class="file-heading">]]
        .. path
        .. [[</h2>
          <div class="file-info">
            <p><strong>Large file (]]
        .. file_data.total_lines
        .. [[ lines) - source view skipped for performance reasons</strong></p>
            <p>Coverage: ]]
        .. file_data.covered_lines
        .. [[ covered of ]]
        .. file_data.executable_lines
        .. [[ executable lines</p>
          </div>
        </div>
      ]]
    end
  end

  -- Generate complete HTML document
  local html = [[<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Coverage Report</title>
  <style>
]] .. SIMPLE_CSS .. [[
  </style>
  <script>
    // Simple theme toggle functionality
    document.addEventListener('DOMContentLoaded', function() {
      const themeToggle = document.getElementById('theme-toggle');
      if (themeToggle) {
        themeToggle.addEventListener('change', function() {
          document.body.classList.toggle('light-theme');
          // Save preference
          localStorage.setItem('theme', document.body.classList.contains('light-theme') ? 'light' : 'dark');
        });

        // Check for saved preference
        const savedTheme = localStorage.getItem('theme');
        if (savedTheme === 'light') {
          document.body.classList.add('light-theme');
          themeToggle.checked = true;
        }
      }
    });
  </script>
</head>
<body>
  <header>
    <div class="container">
      <div style="display: flex; justify-content: space-between; align-items: center;">
        <div>
          <h1>Coverage Report</h1>
          <div style="color: var(--muted-text-dark); font-size: 12px;">Generated on ]] .. os.date("%Y-%m-%d %H:%M:%S") .. [[</div>
        </div>
        <div style="display: flex; align-items: center; gap: 20px;">
          <div class="theme-switch-wrapper">
            <span>🌑</span>
            <label class="theme-switch">
              <input type="checkbox" id="theme-toggle">
              <span class="slider"></span>
            </label>
            <span>☀️</span>
          </div>
          <div>
            <a href="#overview" style="margin-right: 10px; text-decoration: none; color: var(--high-color);">Overview</a>
            <a href="#files" style="text-decoration: none; color: var(--high-color);">Files</a>
          </div>
        </div>
      </div>
    </div>
  </header>

  <div class="container">
    <div id="overview">
      ]] .. overview_html .. [[
    </div>

    <div class="summary" style="margin-bottom: 20px;">
      <h2>Legend</h2>
      <ul style="list-style-type: none; padding-left: 0;">
        <li><div style="display: inline-block; width: 20px; height: 15px; background-color: var(--covered-bg-dark); margin-right: 10px;"></div> <strong>Covered Line:</strong> Line was executed and covered by tests</li>
        <li><div style="display: inline-block; width: 20px; height: 15px; background-color: var(--executed-bg-dark); margin-right: 10px;"></div> <strong>Executed Line:</strong> Line was executed but not explicitly covered by a test</li>
        <li><div style="display: inline-block; width: 20px; height: 15px; background-color: var(--not-covered-bg-dark); margin-right: 10px;"></div> <strong>Not Covered Line:</strong> Executable line that was not executed</li>
        <li><div style="display: inline-block; width: 20px; height: 15px; margin-right: 10px;"></div> <strong>Not Executable Line:</strong> Line that cannot be executed (comment, blank, etc.)</li>
      </ul>
    </div>

    <div id="files">
      ]] .. file_list_html .. [[
    </div>

    <div id="source-sections">
      ]] .. source_sections .. [[
    </div>
  </div>

  <footer>
    <div class="container">
      Coverage report generated by Firmo Coverage v]] .. M._VERSION .. [[
    </div>
  </footer>
</body>
</html>]]

  return html
end

--- Formats quality data into a simple HTML report.
--- Includes interactive "Show Example" buttons for common issues, allowing users to
--- view suggested code snippets for fixes based on the `ISSUE_FIX_EXAMPLES` mapping.
--- It now includes CSS variables for theming with a light/dark theme toggle,
--- a responsive pie chart for summary statistics, and conceptual syntax highlighting
--- for Lua example snippets to improve readability and user experience.
---@param self HTMLFormatter The formatter instance.
---@param quality_data table The quality data structure.
---@param options table Formatting options.
---@return string html_content The HTML report string.
---@private
function HTMLFormatter:_format_quality_html(quality_data, options)
  local lines = {}
  local title = options.title or "Firmo Test Quality Report"
  local summary = quality_data.summary or {}
  local tests = quality_data.tests or {}

  -- Helper to escape HTML characters (already defined globally in this file)

  table.insert(lines, "<!DOCTYPE html>")
  table.insert(lines, "<html lang='en'>")
  table.insert(lines, "<head>")
  table.insert(lines, "  <meta charset='UTF-8'>")
  table.insert(lines, "  <title>" .. escape_html(title) .. "</title>")
  table.insert(lines, "  <style>")
  table.insert(lines, [[
    :root {
      /* Default: Dark Theme */
      --qr-bg-color: #1e1e1e;
      --qr-text-color: #e0e0e0;
      --qr-container-bg: #2c2c2c;
      --qr-container-border: #444;
      --qr-header-color: #f0f0f0;
      --qr-header-border: #555;
      --qr-item-bg: #3a3a3a;
      --qr-item-border: #4a4a4a;
      --qr-link-color: #6bb8ff;
      --qr-button-bg: #555;
      --qr-button-text: #ddd;
      --qr-button-border: #666;
      --qr-button-hover-bg: #6e6e6e;
      --qr-snippet-bg: #303040;
      --qr-snippet-border: #404050;
      --qr-snippet-title-color: #9cdcfe;
      --qr-code-bg: #252526;
      --qr-code-text: #d4d4d4;
      --qr-code-border: #353536;
      --qr-table-header-bg: #404040;
      --qr-table-border: #505050;
      --qr-test-name-color: #87cefa; /* LightSkyBlue */

      /* Pie Chart Colors */
      --qr-pie-color-met: #4CAF50; /* Green */
      --qr-pie-color-not-met: #F44336; /* Red */
      --qr-pie-color-neutral: #757575; /* Grey for no data */

      /* Syntax Highlighting Colors (Dark Theme) */
      --qr-code-keyword-color: #c586c0;  /* Magenta-ish */
      --qr-code-string-color: #ce9178;   /* Orange-ish */
      --qr-code-comment-color: #6a9955;  /* Green-ish */
      --qr-code-number-color: #b5cea8;   /* Light green/blue */
      --qr-code-function-color: #dcdcaa; /* Yellow-ish */
      --qr-code-boolean-color: #569cd6;  /* Blue-ish for true/false/nil */
    }

    body.qr-light-theme {
      --qr-bg-color: #f4f4f4;
      --qr-text-color: #333;
      --qr-container-bg: #ffffff;
      --qr-container-border: #ddd;
      --qr-header-color: #333;
      --qr-header-border: #ccc;
      --qr-item-bg: #f9f9f9;
      --qr-item-border: #eee;
      --qr-link-color: #007bff;
      --qr-button-bg: #e7e7e7;
      --qr-button-text: #333;
      --qr-button-border: #ccc;
      --qr-button-hover-bg: #d7d7d7;
      --qr-snippet-bg: #eef;
      --qr-snippet-border: #ddf;
      --qr-snippet-title-color: #004080;
      --qr-code-bg: #f8f8f8;
      --qr-code-text: #333;
      --qr-code-border: #eee;
      --qr-table-header-bg: #e9e9e9;
      --qr-table-border: #ddd;
      --qr-test-name-color: #0056b3;

      /* Pie Chart Colors */
      --qr-pie-color-met: #28a745; /* Green */
      --qr-pie-color-not-met: #dc3545; /* Red */
      --qr-pie-color-neutral: #bdbdbd; /* Grey for no data */

      /* Syntax Highlighting Colors (Light Theme) */
      --qr-code-keyword-color: #0000ff;  /* Blue */
      --qr-code-string-color: #a31515;   /* Dark red */
      --qr-code-comment-color: #008000;  /* Green */
      --qr-code-number-color: #098658;   /* Dark cyan */
      --qr-code-function-color: #795e26; /* Brown */
      --qr-code-boolean-color: #0000ff;  /* Blue for true/false/nil */
    }

    body {
      font-family: Arial, sans-serif;
      margin: 20px;
      background-color: var(--qr-bg-color);
      color: var(--qr-text-color);
    }
    h1, h2, h3 {
      color: var(--qr-header-color);
      border-bottom: 1px solid var(--qr-header-border);
      padding-bottom: 5px;
    }
    .container {
      background-color: var(--qr-container-bg);
      padding: 20px;
      border-radius: 5px;
      box-shadow: 0 0 10px rgba(0,0,0,0.1); /* This shadow might look off in dark mode, consider conditional styling later */
      border: 1px solid var(--qr-container-border);
      position: relative; /* For positioning theme toggle */
    }
    .qr-theme-toggle-container {
      position: absolute;
      top: 20px;
      right: 20px;
      display: flex;
      align-items: center;
      z-index: 1000; /* Ensure it's on top */
    }
    .qr-theme-toggle-container .qr-theme-icon { /* Base style for icons */
      font-size: 1.2em;
    }
    .qr-theme-toggle-container .qr-moon-icon {
      color: #b0bec5; /* A light, slightly bluish grey, visible on both dark and light backgrounds */
    }
    /* Sun icon (qr-sun-icon) will use its default glyph color which is yellow and works well. */

    .qr-theme-switch {
      position: relative;
      display: inline-block;
      width: 40px;
      height: 20px;
      margin: 0 8px;
    }
    .qr-theme-switch input {
      opacity: 0;
      width: 0;
      height: 0;
    }
    .qr-slider {
      position: absolute;
      cursor: pointer;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background-color: var(--qr-button-bg); /* Use themed button background */
      border-radius: 20px;
      transition: .4s;
    }
    .qr-slider:before {
      position: absolute;
      content: "";
      height: 16px;
      width: 16px;
      left: 2px;
      bottom: 2px;
      background-color: white; /* Knob color */
      border-radius: 50%;
      transition: .4s;
    }
    input:checked + .qr-slider {
      background-color: #2196F3; /* Active color (e.g., when light theme is on) */
    }
    input:checked + .qr-slider:before {
      transform: translateX(20px);
    }
    .summary-item { margin-bottom: 10px; }
    .summary-item strong { display: inline-block; width: 250px; }
    .issues-list, .test-details-list { list-style-type: none; padding-left: 0; }
    .issues-list li, .test-details-list li {
      background-color: var(--qr-item-bg);
      border: 1px solid var(--qr-item-border);
      margin-bottom: 8px;
      padding: 10px;
      border-radius: 3px;
    }
    .issues-list .test-name, .test-details-list .test-name {
      font-weight: bold;
      color: var(--qr-test-name-color);
    }
    .issues-list .issue-text, .test-details-list .issue-text { margin-left: 20px; display: block; }
    table { width: 100%; border-collapse: collapse; margin-top: 15px; }
    th, td {
      border: 1px solid var(--qr-table-border);
      padding: 8px;
      text-align: left;
    }
    th { background-color: var(--qr-table-header-bg); }

    .show-example-btn {
      padding: 2px 8px;
      font-size: 0.8em;
      background-color: var(--qr-button-bg);
      color: var(--qr-button-text);
      border: 1px solid var(--qr-button-border);
      border-radius: 3px;
      cursor: pointer;
      margin-left: 10px;
      white-space: nowrap;
    }
    .show-example-btn:hover {
      background-color: var(--qr-button-hover-bg);
    }
    .fix-example-snippet {
      margin-top: 10px;
      padding: 10px;
      background-color: var(--qr-snippet-bg);
      border: 1px solid var(--qr-snippet-border);
      border-radius: 3px;
    }
    .fix-example-snippet h4 {
      margin-top: 0;
      margin-bottom: 8px;
      font-size: 1.1em;
      color: var(--qr-snippet-title-color);
      border-bottom: none; /* Remove general h1,h2,h3 border for this specific h4 */
    }
    .fix-example-snippet pre {
      margin: 0;
      padding: 10px;
      background-color: var(--qr-code-bg);
      border: 1px solid var(--qr-code-border);
      border-radius: 3px;
      overflow-x: auto;
      color: var(--qr-code-text);
    }
    .fix-example-snippet code {
      font-family: Menlo, Monaco, Consolas, "Courier New", monospace;
      font-size: 0.9em;
      line-height: 1.4;
      display: block; /* Changed from inline for better block behavior */
      /* color: var(--qr-code-text); Already handled by pre */
    }

    /* Minimal Prism-like styles for syntax highlighting */
    pre[class*="language-"] {
      padding: 1em; /* Use existing padding from .fix-example-snippet pre */
      margin: 0; /* Use existing margin from .fix-example-snippet pre */
      overflow: auto; /* Use existing overflow from .fix-example-snippet pre */
      /* background-color: var(--qr-code-bg); Already handled by .fix-example-snippet pre */
      /* border: 1px solid var(--qr-code-border); Already handled by .fix-example-snippet pre */
      /* border-radius: 3px; Already handled by .fix-example-snippet pre */
    }
    code[class*="language-"] {
      /* color: var(--qr-code-text); Already handled by .fix-example-snippet pre */
      background: none;
      text-shadow: none;
      font-family: Menlo, Monaco, Consolas, "Courier New", monospace; /* Already in .fix-example-snippet code */
      font-size: 0.9em; /* Already in .fix-example-snippet code */
      text-align: left;
      white-space: pre;
      word-spacing: normal;
      word-break: normal;
      word-wrap: normal;
      line-height: 1.5; /* Slightly increased from 1.4 for readability */
      tab-size: 2;
      hyphens: none;
    }
    .token.comment, .token.prolog, .token.doctype, .token.cdata {
      color: var(--qr-code-comment-color);
      font-style: italic;
    }
    .token.keyword {
      color: var(--qr-code-keyword-color);
      font-weight: bold;
    }
    .token.string {
      color: var(--qr-code-string-color);
    }
    .token.number {
      color: var(--qr-code-number-color);
    }
    .token.function {
      color: var(--qr-code-function-color);
    }
    .token.boolean { /* covers true, false, nil based on provided JS */
      color: var(--qr-code-boolean-color);
      font-weight: bold;
    }
    .token.operator {
      color: var(--qr-text-color); /* Or a specific operator color */
    }
    .token.punctuation {
      color: var(--qr-text-color); /* Or a specific punctuation color */
    }

    .qr-summary-flex-container {
      display: flex;
      flex-wrap: wrap;
      align-items: flex-start;
      gap: 20px;
      margin-top: 10px; /* Add some space below the H2 */
    }
    .qr-summary-stats-items {
      flex: 2;
      min-width: 280px; /* Adjusted min-width for better spacing of items */
    }
    .qr-pie-chart-container {
      flex: 1;
      min-width: 200px;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding-top: 10px; /* Align with first summary item approximately */
    }
    .qr-pie-chart {
      width: 150px;
      height: 150px;
      border-radius: 50%;
      background-color: var(--qr-item-bg); /* Placeholder background */
      margin-bottom: 15px;
      /* conic-gradient will be applied here by JS/CSS later */
    }
    .qr-pie-chart-legend {
      font-size: 0.9em;
      text-align: left;
      width: 100%;
      max-width: 200px; /* Limit legend width */
    }
    .qr-pie-chart-legend div {
      display: flex;
      align-items: center;
      margin-bottom: 5px;
    }
    .qr-pie-chart-legend .legend-color-swatch {
      width: 12px;
      height: 12px;
      margin-right: 8px;
      border-radius: 2px; /* Square swatches */
    }

    @media (max-width: 768px) {
      .qr-summary-flex-container {
        flex-direction: column;
        align-items: center; /* Center items when stacked */
      }
      .qr-summary-stats-items, .qr-pie-chart-container {
        flex: none;
        width: 100%;
        max-width: 400px; /* Max width for stacked items for readability */
      }
      .qr-pie-chart-container {
        align-items: center;
      }
    }
  ]])
  table.insert(lines, "  </style>")
  table.insert(lines, "</head>")
  table.insert(lines, "<body>")
  table.insert(lines, "  <div class='container'>")
  table.insert(lines, [[
    <div class='qr-theme-toggle-container'>
      <span class="qr-theme-icon qr-moon-icon">🌑</span>
      <label class="qr-theme-switch">
        <input type="checkbox" id="qr-theme-toggle">
        <span class="qr-slider"></span>
      </label>
      <span class="qr-theme-icon qr-sun-icon">☀️</span>
    </div>
  ]])
  table.insert(lines, "    <h1>" .. escape_html(title) .. "</h1>")
  if options.include_timestamp ~= false then
    table.insert(lines, "    <p>Generated: " .. escape_html(os.date("%Y-%m-%d %H:%M:%S")) .. "</p>")
  end

  -- Overall Quality
  table.insert(lines, "    <h2>Overall Quality</h2>")
  table.insert(lines, "    <div class='summary-item'><strong>Achieved Level:</strong> " .. escape_html(quality_data.level_name or "N/A") .. " (" .. escape_html(quality_data.level or 0) .. ")</div>")
  table.insert(lines, "")

  -- Summary Statistics and Pie Chart Section
  table.insert(lines, "    <h2>Summary Statistics</h2>")
  table.insert(lines, "    <div class='qr-summary-flex-container'>") -- Flex container starts
  table.insert(lines, "      <div class='qr-summary-stats-items'>") -- Stats items container starts
  local precision = options.precision or 1
  table.insert(lines, "        <div class='summary-item'><strong>Tests Analyzed:</strong> <span id='stat-tests-analyzed'>" .. escape_html(summary.tests_analyzed or 0) .. "</span></div>")
  table.insert(lines, "        <div class='summary-item'><strong>Tests Meeting Configured Level:</strong> <span id='stat-tests-meeting-level'>" .. escape_html(summary.tests_passing_quality or 0) .. "</span></div>")
  table.insert(lines, "        <div class='summary-item'><strong>Quality Compliance:</strong> " .. escape_html(string.format("%."..precision.."f%%", summary.quality_percent or 0)) .. "</div>")
  table.insert(lines, "        <div class='summary-item'><strong>Total Assertions:</strong> " .. escape_html(summary.assertions_total or 0) .. "</div>")
  table.insert(lines, "        <div class='summary-item'><strong>Avg Assertions/Test:</strong> " .. escape_html(string.format("%."..precision.."f", summary.assertions_per_test_avg or 0)) .. "</div>")
  table.insert(lines, "      </div>") -- Stats items container ends

  table.insert(lines, "      <div class='qr-pie-chart-container'>") -- Pie chart container starts
  table.insert(lines, "        <div id='qr-quality-pie-chart' class='qr-pie-chart' role='img' aria-label='Quality compliance pie chart'></div>")
  table.insert(lines, "        <div id='qr-pie-chart-legend' class='qr-pie-chart-legend'>")
  -- Legend will be populated by JavaScript
  table.insert(lines, "        </div>") -- Legend ends
  table.insert(lines, "      </div>") -- Pie chart container ends
  table.insert(lines, "    </div>") -- Flex container ends
  table.insert(lines, "")

  -- Assertion Types Found (Optional)
  if options.detailed and summary.assertion_types_found and next(summary.assertion_types_found) then
    table.insert(lines, "    <h3>Assertion Types Found</h3>")
    table.insert(lines, "    <ul>")
    for type_name, count in pairs(summary.assertion_types_found) do
      table.insert(lines, "      <li>" .. escape_html(type_name) .. ": " .. escape_html(count) .. "</li>")
    end
    table.insert(lines, "    </ul>")
  end

  -- Overall Issues
  if summary.issues and #summary.issues > 0 then
    table.insert(lines, "    <h2>Overall Issues (" .. escape_html(#summary.issues) .. ")</h2>")
    table.insert(lines, "    <ul class='issues-list'>")
    local max_issues_to_show = (options.show_all_issues == true or options.show_all_issues == nil) and #summary.issues or (options.max_issues or 20)
    for i = 1, math.min(#summary.issues, max_issues_to_show) do
      local issue_obj = summary.issues[i]
      local issue_text_html = "<span class='test-name'>" .. escape_html(issue_obj.test or "N/A") .. ":</span><span class='issue-text'>" .. escape_html(issue_obj.issue or "Unknown") .. "</span>"
      local example_button_html = ""
      local example_div_html = ""
      local example_id = "fix-example-" .. i

      if issue_obj.issue then
        for _, example_entry in ipairs(ISSUE_FIX_EXAMPLES) do
          if string.match(issue_obj.issue, example_entry.key_pattern) then
            example_button_html = "<button class='show-example-btn' data-target-id='" .. example_id .. "'>Show Example</button>"
            example_div_html = "<div id='" .. example_id .. "' class='fix-example-snippet' style='display: none;'>"
              .. "<h4>" .. escape_html(example_entry.title) .. "</h4>"
              .. "<pre><code class=\"language-lua\">" .. escape_html(example_entry.snippet) .. "</code></pre>" -- Use escape_html and add class
              .. "</div>"
            break -- Found a match, no need to check further
          end
        end
      end

      local li_content = "<li>"
        .. "<div style='display: flex; justify-content: space-between; align-items: flex-start;'>"
        .. "<div>" .. issue_text_html .. "</div>"
      if example_button_html ~= "" then
        li_content = li_content .. "<div>" .. example_button_html .. "</div>"
      end
      li_content = li_content .. "</div>"
      if example_div_html ~= "" then
        li_content = li_content .. example_div_html
      end
      li_content = li_content .. "</li>"
      table.insert(lines, "      " .. li_content)
    end
    if #summary.issues > max_issues_to_show then
       table.insert(lines, "      <li>...and " .. escape_html(#summary.issues - max_issues_to_show) .. " more issues.</li>")
    end
    table.insert(lines, "    </ul>")
  else
    table.insert(lines, "    <h2>Overall Issues</h2>")
    table.insert(lines, "    <p>No overall quality issues found.</p>")
  end
  table.insert(lines, "")

  -- Per-Test Details (Optional and basic for now)
  if options.detailed and tests and next(tests) then
    table.insert(lines, "    <h2>Per-Test Quality Details</h2>")
    table.insert(lines, "    <table><thead><tr><th>Test Name</th><th>Achieved Level</th><th>Issues</th></tr></thead><tbody>")
    local tests_sorted = {}
    for test_name_key, test_info_val in pairs(tests) do table.insert(tests_sorted, { name = test_name_key, info = test_info_val }) end
    table.sort(tests_sorted, function(a,b) return a.name < b.name end)
    
    local max_tests_to_show = (options.show_all_tests == true or options.show_all_tests == nil) and #tests_sorted or (options.max_files or 25)
    for i = 1, math.min(#tests_sorted, max_tests_to_show) do
        local item = tests_sorted[i]
        local test_name = item.name
        local test_info = item.info
        local achieved_level = test_info.quality_level or 0
        local level_name_str = quality_module and quality_module.get_level_name(achieved_level) or tostring(achieved_level)
        
        table.insert(lines, "      <tr>")
        table.insert(lines, "        <td>" .. escape_html(test_name) .. "</td>")
        table.insert(lines, "        <td>" .. escape_html(level_name_str) .. " (" .. escape_html(achieved_level) .. ")</td>")
        local issues_html = ""
        if test_info.issues and #test_info.issues > 0 then
            issues_html = "<ul>"
            for _, issue_text in ipairs(test_info.issues) do
                issues_html = issues_html .. "<li>" .. escape_html(issue_text) .. "</li>"
            end
            issues_html = issues_html .. "</ul>"
        else
            issues_html = "None"
        end
        table.insert(lines, "        <td>" .. issues_html .. "</td>")
        table.insert(lines, "      </tr>")
    end
    table.insert(lines, "    </tbody></table>")
    if #tests_sorted > max_tests_to_show then
       table.insert(lines, "    <p>...and " .. escape_html(#tests_sorted - max_tests_to_show) .. " more tests.</p>")
    end
  end

  table.insert(lines, "  </div>")
  table.insert(lines, "  <script>")
  table.insert(lines, [[
document.addEventListener('DOMContentLoaded', function() {
  // Theme Toggle Logic
  const themeToggle = document.getElementById('qr-theme-toggle');
  const body = document.body;

  function applyTheme(theme) {
    if (theme === 'light') {
      body.classList.add('qr-light-theme');
      if (themeToggle) themeToggle.checked = true;
    } else { // 'dark' or default
      body.classList.remove('qr-light-theme');
      if (themeToggle) themeToggle.checked = false;
    }
  }

  const savedTheme = localStorage.getItem('qr-theme');
  if (savedTheme) {
    applyTheme(savedTheme);
  } else {
    applyTheme('dark'); // Default to dark theme
  }

  if (themeToggle) {
    themeToggle.addEventListener('change', function() {
      if (this.checked) {
        applyTheme('light');
        localStorage.setItem('qr-theme', 'light');
      } else {
        applyTheme('dark');
        localStorage.setItem('qr-theme', 'dark');
      }
    });
  }

  // Show Example Button Logic
  const buttons = document.querySelectorAll('.show-example-btn');
  buttons.forEach(function(button) {
    button.addEventListener('click', function() {
      const targetId = this.dataset.targetId;
      const targetDiv = document.getElementById(targetId);
      if (targetDiv) {
        if (targetDiv.style.display === 'none' || targetDiv.style.display === '') {
          targetDiv.style.display = 'block';
          this.textContent = 'Hide Example';
        } else {
          targetDiv.style.display = 'none';
          this.textContent = 'Show Example';
        }
      }
    });
  });

  // Pie Chart Logic
  const pieChartDiv = document.getElementById('qr-quality-pie-chart');
  const legendDiv = document.getElementById('qr-pie-chart-legend');
  const testsAnalyzedSpan = document.getElementById('stat-tests-analyzed');
  const testsMeetingLevelSpan = document.getElementById('stat-tests-meeting-level');

  if (pieChartDiv && legendDiv && testsAnalyzedSpan && testsMeetingLevelSpan) {
    const testsAnalyzed = parseInt(testsAnalyzedSpan.textContent, 10) || 0;
    const testsMeetingLevel = parseInt(testsMeetingLevelSpan.textContent, 10) || 0;

    const style = getComputedStyle(document.documentElement);
    const colorMet = style.getPropertyValue('--qr-pie-color-met').trim() || '#28a745';
    const colorNotMet = style.getPropertyValue('--qr-pie-color-not-met').trim() || '#dc3545';
    const colorNeutral = style.getPropertyValue('--qr-pie-color-neutral').trim() || '#bdbdbd';

    legendDiv.innerHTML = ''; // Clear legend

    if (testsAnalyzed > 0) {
      const percentMet = (testsMeetingLevel / testsAnalyzed) * 100;
      const testsNotMeeting = testsAnalyzed - testsMeetingLevel;
      const percentNotMet = (testsNotMeeting / testsAnalyzed) * 100;

      pieChartDiv.style.background = `conic-gradient(${colorMet} 0% ${percentMet.toFixed(1)}%, ${colorNotMet} ${percentMet.toFixed(1)}% 100%)`;

      const legendItemMet = document.createElement('div');
      legendItemMet.innerHTML = `<span class="legend-color-swatch" style="background-color: ${colorMet};"></span> Tests Meeting Level (${testsMeetingLevel} - ${percentMet.toFixed(1)}%)`;
      legendDiv.appendChild(legendItemMet);

      const legendItemNotMet = document.createElement('div');
      legendItemNotMet.innerHTML = `<span class="legend-color-swatch" style="background-color: ${colorNotMet};"></span> Tests Not Meeting Level (${testsNotMeeting} - ${percentNotMet.toFixed(1)}%)`;
      legendDiv.appendChild(legendItemNotMet);

    } else {
      pieChartDiv.style.background = colorNeutral; // Neutral color if no data
      const noDataItem = document.createElement('div');
      noDataItem.textContent = 'No tests analyzed.';
      legendDiv.appendChild(noDataItem);
    }
  }

  // --- Start of Conceptual Prism.js for Lua ---
  var Prism = {
    manual: true, // We call highlightAll manually
    languages: {
      lua: {
        'comment': /--.*/,
        'string': /(["'])(?:(?=(\\?))\2.)*?\1/,
        'keyword': /\b(?:and|break|do|else|elseif|end|false|for|function|if|in|local|nil|not|or|repeat|return|then|true|until|while)\b/,
        'function': /\b([a-zA-Z_]\w*)\s*(?=\()/, // Lookahead for (
        'number': /\b0x[0-9a-fA-F]+(?:\.\w*)?|\b\d*\.?\d+(?:[eE][+-]?\d+)?|\b\d+\b/,
        'boolean': /\b(?:true|false|nil)\b/,
        'operator': /[\+\-\*\/%#<>=~]=?|[\.]{2,3}|\.\.\.=?/, // Added ... and ...=
        'punctuation': /[\(\)\[\]\{\}\.,;\:]/ // Added comma and period
      }
    },
    highlightElement: function(element) {
      if (!element || !Prism.languages.lua) return;
      let code = element.textContent;
      const grammar = Prism.languages.lua;
      let html = '';

      // Very basic greedy tokenizer (order matters for overlapping patterns)
      // This is a simplified approach. Real Prism.js uses a more sophisticated graph-based tokenizer.
      const tokenTypes = ['comment', 'string', 'keyword', 'function', 'number', 'boolean', 'operator', 'punctuation'];
      let lastIndex = 0;

      // Create a combined regex (simplified, real Prism is more complex)
      // This approach won't handle nested patterns well without lookbehinds or complex logic
      // For a simple demo, we'll iterate and replace greedily.
      // A better simplified approach might be to find all matches with indices first.

      // For this conceptual version, let's do a multi-pass replace which is not ideal but simpler to write here.
      // A real implementation would tokenize into a flat list of strings and token objects.
      
      // Pass 1: Comments (they can contain anything)
      code = code.replace(new RegExp(grammar.comment.source, 'g'), function(match) {
        return '<span class="token comment">' + match.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;') + '</span>';
      });
      // Pass 2: Strings
      code = code.replace(new RegExp(grammar.string.source, 'g'), function(match) {
        // Avoid re-highlighting comments within strings if a comment was already tagged.
        if (match.includes('<span class="token comment">')) return match;
        return '<span class="token string">' + match.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;') + '</span>';
      });
      // Other passes (keywords, numbers, etc.) would also need similar protection against re-highlighting.
      // This becomes very complex quickly with simple regex replaces.
      // For now, this is a placeholder for what a real library would do.
      // The key is that Prism.highlightAll() would be called, and it would handle this robustly.
      // For this example, we'll just use a few direct replacements on the original textContent
      // without proper tokenization for simplicity of this conceptual snippet.

      let originalCode = element.textContent; // Use original for replacements
      const replacements = [];

      function addReplacement(className, regex) {
        let match;
        const globalRegex = new RegExp(regex.source, 'g'); // Ensure global flag for exec loop
        while ((match = globalRegex.exec(originalCode)) !== null) {
          replacements.push({
            start: match.index,
            end: match.index + match[0].length,
            className: className,
            text: match[0]
          });
        }
      }

      addReplacement('comment', grammar.comment);
      addReplacement('string', grammar.string);
      addReplacement('keyword', grammar.keyword);
      addReplacement('function', grammar.function);
      addReplacement('number', grammar.number);
      addReplacement('boolean', grammar.boolean);
      addReplacement('operator', grammar.operator);
      addReplacement('punctuation', grammar.punctuation);

      // Sort by start index, then by length descending to prioritize longer matches
      replacements.sort((a, b) => {
        if (a.start !== b.start) return a.start - b.start;
        return (b.end - b.start) - (a.end - a.start);
      });

      let resultHtml = '';
      let currentIndex = 0;
      const appliedRanges = [];

      function isOverlapping(start, end) {
        for (const range of appliedRanges) {
          if (start < range.end && end > range.start) return true;
        }
        return false;
      }

      for (const rep of replacements) {
        if (rep.start >= currentIndex && !isOverlapping(rep.start, rep.end)) {
          resultHtml += originalCode.substring(currentIndex, rep.start).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
          resultHtml += `<span class="token ${rep.className}">${rep.text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')}</span>`;
          currentIndex = rep.end;
          appliedRanges.push({start: rep.start, end: rep.end});
        }
      }
      resultHtml += originalCode.substring(currentIndex).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
      element.innerHTML = resultHtml;
    },
    highlightAll: function() {
      document.querySelectorAll('code.language-lua').forEach(Prism.highlightElement);
    }
  };
  // --- End of Conceptual Prism.js ---

  // Call highlightAll
  if (typeof Prism !== 'undefined' && Prism.highlightAll) {
    Prism.highlightAll();
  }
});
  ]])
  table.insert(lines, "  </script>")
  table.insert(lines, "</body>")
  table.insert(lines, "</html>")

  return table.concat(lines, "\n")
end

--- Formats data (coverage or quality) into HTML content.
---@param self HTMLFormatter The formatter instance.
---@param data table The data to format (coverage or quality).
---@param options? table Formatting options.
---@return string|nil html_content The generated HTML content, or nil on error.
---@return table? err Error object if formatting failed.
function HTMLFormatter:format(data, options)
  options = self:_merge_options(options or {}) -- Ensure options are merged and defaults applied

  if not data then
    return nil, get_error_handler().validation_error("Input data is required", { formatter = self.name })
  end

  local html_content
  if data.report_type == "quality" then
    get_logger().debug("Formatting quality data as HTML", { data_keys = self:get_table_keys(data) })
    html_content = self:_format_quality_html(data, options)
  elseif data.report_type == "coverage" or (not data.report_type and data.files and data.summary) then -- Assuming coverage
    get_logger().debug("Formatting coverage data as HTML", { data_keys = self:get_table_keys(data) })
    local normalized_data = self:normalize_coverage_data(data)
    html_content = self:_build_html_report(normalized_data, options) -- Existing method for coverage
  else
    return nil, get_error_handler().validation_error("Unsupported data structure for HTML formatter", {
      formatter = self.name,
      data_type = type(data),
      report_type = data.report_type,
    })
  end

  if not html_content then
    return nil, get_error_handler().runtime_error("HTML content generation failed", { formatter = self.name })
  end

  return html_content
end

--- Generates and writes the HTML coverage report file.
--- Applies performance optimizations (simplified rendering for large files) before formatting.
--- Ensures output directory exists and writes the generated HTML.
---@param coverage_data CoverageReportData The coverage data structure.
---@param output_path string The path where the HTML report file should be saved. If it ends in "/", "coverage-report.html" is appended.
---@return boolean success `true` if the report was generated and written successfully.
---@return table? error Error object if validation, formatting, or file operations failed.
---@throws table If input validation fails (via `error_handler.assert`) or if directory creation/file writing fails critically.
function M.generate(coverage_data, output_path)
  -- Parameter validation
  get_error_handler().assert(
    type(coverage_data) == "table",
    "coverage_data must be a table",
    get_error_handler().CATEGORY.VALIDATION
  )
  get_error_handler().assert(type(output_path) == "string", "output_path must be a string", get_error_handler().CATEGORY.VALIDATION)

  -- If output_path is a directory, add a filename
  if output_path:sub(-1) == "/" then
    output_path = output_path .. "coverage-report.html"
  end

  -- Try to ensure the directory exists
  local dir_path = output_path:match("(.+)/[^/]+$")
  if dir_path then
    local mkdir_success, mkdir_err = get_fs().ensure_directory_exists(dir_path)
    if not mkdir_success then
      get_logger().warn("Failed to ensure directory exists, but will try to write anyway", {
        directory = dir_path,
        error = mkdir_err and get_error_handler().format_error(mkdir_err) or "Unknown error",
      })
    end
  end

  -- PERFORMANCE OPTIMIZATION: Filter large files to improve report generation speed
  -- This applies universally to all files based only on their size characteristics
  local filtered_coverage_data = {
    summary = coverage_data.summary,
    files = {},
    executed_lines = coverage_data.executed_lines,
    covered_lines = coverage_data.covered_lines,
  }

  -- Set maximum file size for full inclusion - anything larger will be represented
  -- by a summary only. This is a performance constraint, not a special case.
  local max_lines_for_full_inclusion = 1000

  -- Process files based on size thresholds (applies to ALL files equally)
  local file_count = 0
  local skipped_count = 0
  for path, file_data in pairs(coverage_data.files) do
    -- Include all files, but mark large ones for simplified rendering
    if file_data.total_lines < max_lines_for_full_inclusion then
      -- Small files get full treatment
      filtered_coverage_data.files[path] = file_data
    else
      -- Large files get included with a size flag for optimized rendering
      filtered_coverage_data.files[path] = file_data
      filtered_coverage_data.files[path].simplified_rendering = true
    end
    file_count = file_count + 1
  end

  get_logger().info("Generating report with performance optimization", {
    total_files = file_count,
    max_lines_threshold = max_lines_for_full_inclusion,
  })

  -- Generate the HTML content using the filtered data
  local html = M.format_coverage(filtered_coverage_data)

  -- Write the report to the output file
  local success, err = get_error_handler().safe_io_operation(function()
    return get_fs().write_file(output_path, html)
  end, output_path, { operation = "write_coverage_report" })

  if not success then
    get_logger().error("Failed to write HTML coverage report", {
      file_path = output_path,
      error = get_error_handler().format_error(err),
    })
    return false, err
  end

  get_logger().info("Successfully wrote HTML coverage report", {
    file_path = output_path,
    report_size = #html,
  })

  return true
end

--- Registers the HTML formatter with the main formatters registry.
---@param formatters table The main formatters registry object.
---@return boolean success True if registration was successful.
---@return table? err Error object if registration failed.
function HTMLFormatter.register(formatters)
  if not formatters or type(formatters) ~= "table" then
    return false, get_error_handler().validation_error("Invalid formatters registry", { formatter = "html" })
  end

  local formatter_instance = HTMLFormatter.new()

  -- Register for coverage reports
  formatters.coverage = formatters.coverage or {}
  formatters.coverage.html = function(data, opts)
    return formatter_instance:format(data, opts)
  end

  -- Register for quality reports
  formatters.quality = formatters.quality or {}
  formatters.quality.html = function(data, opts)
    return formatter_instance:format(data, opts)
  end

  return true
end

return HTMLFormatter
