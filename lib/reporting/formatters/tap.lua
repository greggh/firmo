--- TAP Formatter for Coverage Reports
-- Generates Test Anything Protocol (TAP) format coverage reports
-- @module reporting.formatters.tap
-- @author Firmo Team
-- @version 1.0.0

local Formatter = require("lib.reporting.formatters.base")
local error_handler = require("lib.tools.error_handler")
local central_config = require("lib.core.central_config")
local filesystem = require("lib.tools.filesystem")

-- Create TAP formatter class
local TAPFormatter = Formatter.extend("tap", "tap")

--- TAP Formatter version
TAPFormatter._VERSION = "1.0.0"

-- Validate coverage data structure for TAP formatter
function TAPFormatter:validate(coverage_data)
  -- Call base class validation first
  local valid, err = Formatter.validate(self, coverage_data)
  if not valid then
    return false, err
  end

  -- Additional TAP-specific validation if needed

  return true
end

-- Format coverage data as TAP
function TAPFormatter:format(coverage_data, options)
  -- Parameter validation
  if not coverage_data then
    return nil, error_handler.validation_error("Coverage data is required", { formatter = self.name })
  end

  -- Apply options with defaults
  options = options or {}
  options.threshold = options.threshold or 80
  options.file_threshold = options.file_threshold or options.threshold
  options.detailed = options.detailed ~= false -- Default to true

  -- Normalize the coverage data
  local normalized_data = self:normalize_coverage_data(coverage_data)

  -- Begin building TAP content
  local tap_content = self:build_tap(normalized_data, options)

  return tap_content
end

-- Build TAP format content
function TAPFormatter:build_tap(data, options)
  local lines = {}

  -- Add TAP header
  table.insert(lines, "TAP version 13")

  -- Calculate how many tests we'll run
  local test_count = 1 -- Start with the overall coverage test

  -- Add file tests if we have files
  if data.files then
    test_count = test_count + #self:get_table_keys(data.files)
  end

  -- Add TAP plan line
  table.insert(lines, "1.." .. test_count)

  -- Check overall coverage first
  local overall_threshold = options.threshold or 80
  local overall_coverage = data.summary.coverage_percent or 0
  local overall_test_passed = overall_coverage >= overall_threshold

  -- Add overall coverage test
  if overall_test_passed then
    table.insert(lines, "ok 1 - Overall coverage meets threshold")
  else
    table.insert(lines, "not ok 1 - Overall coverage below threshold")
  end

  -- Add overall coverage details as YAML diagnostic
  if options.detailed then
    table.insert(lines, "  ---")
    table.insert(lines, "  threshold: " .. overall_threshold .. "%")
    table.insert(lines, "  coverage: " .. string.format("%.2f", overall_coverage) .. "%")
    table.insert(lines, "  total_files: " .. data.summary.total_files)
    table.insert(lines, "  total_lines: " .. data.summary.total_lines)
    table.insert(lines, "  covered_lines: " .. data.summary.covered_lines)
    table.insert(lines, "  executed_lines: " .. data.summary.executed_lines)
    table.insert(lines, "  not_covered_lines: " .. data.summary.not_covered_lines)
    table.insert(lines, "  ...")
  end

  -- Process each file
  local sorted_files = {}
  for path, file_data in pairs(data.files or {}) do
    table.insert(sorted_files, { path = path, data = file_data })
  end

  table.sort(sorted_files, function(a, b)
    return a.path < b.path
  end)

  -- Add each file's coverage as a test
  for i, file in ipairs(sorted_files) do
    local test_number = i + 1 -- Start from 2 since overall is test 1
    local path = file.path
    local file_data = file.data
    local file_threshold = options.file_threshold or 80
    local file_coverage = file_data.summary.coverage_percent or 0
    local file_test_passed = file_coverage >= file_threshold

    -- Add file coverage test
    if file_test_passed then
      table.insert(lines, "ok " .. test_number .. " - " .. path)
    else
      table.insert(lines, "not ok " .. test_number .. " - " .. path)
    end

    -- Add file coverage details as YAML diagnostic
    if options.detailed then
      table.insert(lines, "  ---")
      table.insert(lines, "  threshold: " .. file_threshold .. "%")
      table.insert(lines, "  coverage: " .. string.format("%.2f", file_coverage) .. "%")
      table.insert(lines, "  total_lines: " .. file_data.summary.total_lines)
      table.insert(lines, "  covered_lines: " .. file_data.summary.covered_lines)
      table.insert(lines, "  executed_lines: " .. file_data.summary.executed_lines)
      table.insert(lines, "  not_covered_lines: " .. file_data.summary.not_covered_lines)

      -- Add function coverage if available
      if file_data.functions and next(file_data.functions) then
        table.insert(lines, "  functions:")

        -- Count covered and uncovered functions
        local covered_functions = 0
        local total_functions = 0

        for name, func_data in pairs(file_data.functions) do
          total_functions = total_functions + 1
          if func_data.executed or (func_data.execution_count and func_data.execution_count > 0) then
            covered_functions = covered_functions + 1
          end
        end

        table.insert(lines, "    total: " .. total_functions)
        table.insert(lines, "    covered: " .. covered_functions)

        -- List uncovered functions if any and if we should be detailed
        if options.list_uncovered and covered_functions < total_functions then
          table.insert(lines, "    uncovered:")

          -- Sort function names for consistency
          local func_names = {}
          for name, func_data in pairs(file_data.functions) do
            if not (func_data.executed or (func_data.execution_count and func_data.execution_count > 0)) then
              table.insert(func_names, {
                name = name,
                line = func_data.start_line or 0,
              })
            end
          end

          table.sort(func_names, function(a, b)
            return a.line < b.line
          end)

          for _, func in ipairs(func_names) do
            table.insert(lines, "      - name: " .. func.name)
            table.insert(lines, "        line: " .. func.line)
          end
        end
      end

      -- Add uncovered lines if configured
      if options.list_uncovered_lines and file_data.lines then
        local uncovered_lines = {}

        for line_num, line_data in pairs(file_data.lines) do
          if
            not (
              line_data.covered
              or line_data.executed
              or (line_data.execution_count and line_data.execution_count > 0)
            )
          then
            table.insert(uncovered_lines, tonumber(line_num))
          end
        end

        if #uncovered_lines > 0 then
          table.sort(uncovered_lines)

          table.insert(lines, "  uncovered_lines:")

          -- Group consecutive lines for readability
          local ranges = {}
          local current_range = { start = uncovered_lines[1], end_ = uncovered_lines[1] }

          for i = 2, #uncovered_lines do
            if uncovered_lines[i] == current_range.end_ + 1 then
              -- Continue the current range
              current_range.end_ = uncovered_lines[i]
            else
              -- End the current range and start a new one
              table.insert(ranges, current_range)
              current_range = { start = uncovered_lines[i], end_ = uncovered_lines[i] }
            end
          end

          -- Add the last range
          table.insert(ranges, current_range)

          -- Output ranges
          for _, range in ipairs(ranges) do
            if range.start == range.end_ then
              table.insert(lines, "    - " .. range.start)
            else
              table.insert(lines, "    - " .. range.start .. "-" .. range.end_)
            end
          end
        end
      end

      table.insert(lines, "  ...")
    end
  end

  -- Add TAP summary
  local pass_count = 0
  local fail_count = 0

  if overall_test_passed then
    pass_count = pass_count + 1
  else
    fail_count = fail_count + 1
  end

  for _, file in ipairs(sorted_files) do
    local file_threshold = options.file_threshold or 80
    local file_coverage = file.data.summary.coverage_percent or 0

    if file_coverage >= file_threshold then
      pass_count = pass_count + 1
    else
      fail_count = fail_count + 1
    end
  end

  -- Add TAP summary as a comment
  table.insert(lines, "# Tests " .. test_count)
  table.insert(lines, "# Pass " .. pass_count)
  table.insert(lines, "# Fail " .. fail_count)

  -- Join all lines with newlines
  return table.concat(lines, "\n")
end

-- Write the report to the filesystem
function TAPFormatter:write(tap_content, output_path, options)
  return Formatter.write(self, tap_content, output_path, options)
end

--- Register the TAP formatter with the formatters registry
-- @param formatters table The formatters registry
-- @return boolean success Whether registration was successful
function TAPFormatter.register(formatters)
  if not formatters or type(formatters) ~= "table" then
    local err = error_handler.validation_error("Invalid formatters registry", {
      operation = "register",
      formatter = "tap",
      provided_type = type(formatters),
    })
    return false, err
  end

  -- Create a new instance of the formatter
  local formatter = TAPFormatter.new()

  -- Register format_coverage function
  formatters.coverage.tap = function(coverage_data, options)
    return formatter:format(coverage_data, options)
  end

  return true
end

return TAPFormatter
