--- Level-specific quality checkers for Firmo quality module
--- This module provides specialized validation functions for each quality level,
--- evaluating tests against the specific requirements of each level.
---
--- The module implements the single responsibility principle by focusing only on
--- level-specific validation logic, separate from the main quality module.
---
--- Each level checker evaluates a single test against the relevant requirements
--- and returns standardized validation results.
---
--- @version 0.2.0
--- @author Firmo Team

-- Local dependencies
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

-- Create module logger
local logger = logging.get_logger("Quality.LevelCheckers")

-- Configure module logging
logging.configure_from_config("Quality.LevelCheckers")

local M = {}

-- Helper Functions ------------------------------------------------------

--- Check if a string value contains the specified Lua pattern
---@private
---@param value any The value to check for pattern matching (must be a string)
---@param pattern string The Lua pattern to search for in the value
---@return boolean contains True if value contains the pattern, false otherwise or if value is not a string
local function contains_pattern(value, pattern)
  if type(value) ~= "string" then
    return false
  end
  return string.find(value, pattern) ~= nil
end

--- Check if a string value contains any of the specified Lua patterns
---@private
---@param value any The value to check for pattern matching (must be a string)
---@param patterns string[] Array of Lua patterns to search for in the value
---@return boolean contains True if value contains any of the patterns, false otherwise
local function contains_any_pattern(value, patterns)
  if type(value) ~= "string" or not patterns or #patterns == 0 then
    return false
  end
  
  for _, pattern in ipairs(patterns) do
    if contains_pattern(value, pattern) then
      return true
    end
  end
  
  return false
end

-- Level Requirement Checkers --------------------------------------------

--- Check if a test has enough assertions
---@param test_info table The test info object containing assertion data
---@param requirements table The requirements for the specified quality level
---@return boolean is_valid Whether the test meets the assertion count requirements
---@return string? issue Optional issue description if requirements not met
function M.check_assertion_count(test_info, requirements)
  local min_required = requirements.min_assertions_per_test or 1
  local max_allowed = (requirements.test_organization and requirements.test_organization.max_assertions_per_test) or 15
  
  if test_info.assertion_count < min_required then
    return false, string.format(
      "Too few assertions: found %d, need at least %d", 
      test_info.assertion_count, 
      min_required
    )
  end
  
  if test_info.assertion_count > max_allowed then
    return false, string.format(
      "Too many assertions: found %d, maximum is %d", 
      test_info.assertion_count, 
      max_allowed
    )
  end
  
  return true
end

--- Check if a test uses required assertion types
---@param test_info table The test info object containing assertion type data
---@param requirements table The requirements for the specified quality level
---@return boolean is_valid Whether the test meets the assertion type requirements
---@return string? issue Optional issue description if requirements not met
function M.check_assertion_types(test_info, requirements)
  local required_types = requirements.assertion_types_required or {}
  local min_types_required = requirements.assertion_types_required_count or 1
  
  local found_types = 0
  local types_found = {}
  
  for _, required_type in ipairs(required_types) do
    if test_info.assertion_types[required_type] and test_info.assertion_types[required_type] > 0 then
      found_types = found_types + 1
      types_found[required_type] = true
    end
  end
  
  if found_types < min_types_required then
    local missing_types = {}
    for _, required_type in ipairs(required_types) do
      if not types_found[required_type] then
        table.insert(missing_types, required_type)
      end
    end
    
    return false, string.format(
      "Missing required assertion types: need %d type(s), found %d. Missing: %s", 
      min_types_required, 
      found_types,
      table.concat(missing_types, ", ")
    )
  end
  
  return true
end

--- Check if test organization meets requirements
---@param test_info table The test info object containing organization data
---@param requirements table The requirements for the specified quality level
---@return boolean is_valid Whether the test meets the organization requirements
---@return string[]? issues Optional array of issues if requirements not met
function M.check_organization(test_info, requirements)
  if not requirements.test_organization then
    return true
  end
  
  local org = requirements.test_organization
  local is_valid = true
  local issues = {}
  
  -- Check for describe blocks
  if org.require_describe_block and not test_info.has_describe then
    table.insert(issues, "Missing describe block")
    is_valid = false
  end
  
  -- Check for it blocks
  if org.require_it_block and not test_info.has_it then
    table.insert(issues, "Missing it block")
    is_valid = false
  end
  
  -- Check for proper test naming
  if org.require_test_name and not test_info.has_proper_name then
    table.insert(issues, "Test doesn't have a proper descriptive name")
    is_valid = false
  end
  
  -- Check for before/after blocks
  if org.require_before_after and not test_info.has_before_after then
    table.insert(issues, "Missing setup/teardown with before/after blocks")
    is_valid = false
  end
  
  -- Check for context nesting
  if org.require_context_nesting and test_info.nesting_level < 2 then
    table.insert(issues, "Insufficient context nesting (need at least 2 levels)")
    is_valid = false
  end
  
  -- Check for mock verification
  if org.require_mock_verification and not test_info.has_mock_verification then
    table.insert(issues, "Missing mock/spy verification")
    is_valid = false
  end
  
  -- Check for performance tests
  if org.require_performance_tests and not test_info.has_performance_tests then
    table.insert(issues, "Missing performance tests")
    is_valid = false
  end
  
  -- Check for security tests
  if org.require_security_tests and not test_info.has_security_tests then
    table.insert(issues, "Missing security tests")
    is_valid = false
  end
  
  return is_valid, issues
end

--- Check for coverage threshold requirements
---@param test_info table The test info object (not used here but included for consistent interface)
---@param requirements table The requirements for the specified quality level
---@param coverage_data? table Optional coverage data from coverage module
---@return boolean is_valid Whether coverage meets the requirements
---@return string? issue Optional issue description if requirements not met
function M.check_coverage(test_info, requirements, coverage_data)
  -- Skip if no coverage requirements or no coverage data
  if not requirements.test_organization or 
     not requirements.test_organization.require_coverage_threshold or 
     not coverage_data then
    return true
  end
  
  local threshold = requirements.test_organization.require_coverage_threshold
  
  -- Get overall coverage percentage
  local overall_pct = 0
  if coverage_data.summary and coverage_data.summary.coverage_percent then
    overall_pct = coverage_data.summary.coverage_percent
  elseif coverage_data.overall_pct then
    overall_pct = coverage_data.overall_pct
  end
  
  if overall_pct < threshold then
    return false, string.format(
      "Insufficient code coverage: %.2f%% (threshold: %d%%)",
      overall_pct,
      threshold
    )
  end
  
  return true
end

--- Check for required patterns
---@param test_info table The test info object containing patterns found
---@param requirements table The requirements for the specified quality level
---@return boolean is_valid Whether the test meets the pattern requirements
---@return string? issue Optional issue description if requirements not met
function M.check_required_patterns(test_info, requirements)
  local required_patterns = requirements.required_patterns or {}
  if #required_patterns == 0 then
    return true
  end
  
  local is_valid = true
  local missing_patterns = {}
  
  for _, pattern in ipairs(required_patterns) do
    if not test_info.patterns_found[pattern] then
      table.insert(missing_patterns, pattern)
      is_valid = false
    end
  end
  
  if #missing_patterns > 0 then
    return false, string.format(
      "Missing required patterns: %s", 
      table.concat(missing_patterns, ", ")
    )
  end
  
  return true
end

--- Check for forbidden patterns
---@param test_info table The test info object containing patterns found
---@param requirements table The requirements for the specified quality level
---@return boolean is_valid Whether the test has no forbidden patterns
---@return string? issue Optional issue description if requirements not met
function M.check_forbidden_patterns(test_info, requirements)
  local forbidden_patterns = requirements.forbidden_patterns or {}
  if #forbidden_patterns == 0 then
    return true
  end
  
  local is_valid = true
  local found_forbidden = {}
  
  for _, pattern in ipairs(forbidden_patterns) do
    if test_info.patterns_found[pattern] then
      table.insert(found_forbidden, pattern)
      is_valid = false
    end
  end
  
  if #found_forbidden > 0 then
    return false, string.format(
      "Found forbidden patterns: %s", 
      table.concat(found_forbidden, ", ")
    )
  end
  
  return true
end

-- Level-Specific Evaluation Functions -----------------------------------

--- Evaluate a test against level 1 (Basic) requirements
---@param test_info table The test info object with test metadata
---@param coverage_data? table Optional coverage data
---@return {passes: boolean, score: number, issues: string[], requirements_met: number, total_requirements: number} result Evaluation results
function M.evaluate_level_1(test_info, coverage_data)
  local requirements = {
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
  
  return M.evaluate_test_against_requirements(test_info, requirements, coverage_data)
end

--- Evaluate a test against level 2 (Standard) requirements
---@param test_info table The test info object with test metadata
---@param coverage_data? table Optional coverage data
---@return {passes: boolean, score: number, issues: string[], requirements_met: number, total_requirements: number} result Evaluation results
function M.evaluate_level_2(test_info, coverage_data)
  local requirements = {
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
  
  return M.evaluate_test_against_requirements(test_info, requirements, coverage_data)
end

--- Evaluate a test against level 3 (Comprehensive) requirements
---@param test_info table The test info object with test metadata
---@param coverage_data? table Optional coverage data
---@return {passes: boolean, score: number, issues: string[], requirements_met: number, total_requirements: number} result Evaluation results
function M.evaluate_level_3(test_info, coverage_data)
  local requirements = {
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
  
  return M.evaluate_test_against_requirements(test_info, requirements, coverage_data)
end

--- Evaluate a test against level 4 (Advanced) requirements
---@param test_info table The test info object with test metadata
---@param coverage_data? table Optional coverage data
---@return {passes: boolean, score: number, issues: string[], requirements_met: number, total_requirements: number} result Evaluation results
function M.evaluate_level_4(test_info, coverage_data)
  local requirements = {
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
  
  
  return M.evaluate_test_against_requirements(test_info, requirements, coverage_data)
end

--- Evaluate a test against level 5 (Complete) requirements
---@param test_info table The test info object with test metadata
---@param coverage_data? table Optional coverage data
---@return {passes: boolean, score: number, issues: string[], requirements_met: number, total_requirements: number} result Evaluation results
function M.evaluate_level_5(test_info, coverage_data)
  local requirements = {
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
      require_coverage_threshold = 90, -- Match our new standard threshold
      require_performance_tests = true,
      require_security_tests = true
    },
    required_patterns = {"should", "when", "boundary", "security", "performance"},
    forbidden_patterns = {"SKIP", "TODO", "FIXME"},
  }
  
  return M.evaluate_test_against_requirements(test_info, requirements, coverage_data)
end

--- Core evaluation function that checks test against a set of requirements
---@param test_info table The test info object with test metadata
---@param requirements table The requirements to check against
---@param coverage_data? table Optional coverage data from coverage module
---@return {passes: boolean, score: number, issues: string[], requirements_met: number, total_requirements: number} result Evaluation results
function M.evaluate_test_against_requirements(test_info, requirements, coverage_data)
  -- Initialize result object
  local result = {
    passes = true,
    score = 0,
    issues = {},
    requirements_met = 0,
    total_requirements = 5  -- Five main requirement categories
  }
  
  -- 1. Check assertion count
  local assertion_count_valid, assertion_count_issue = M.check_assertion_count(test_info, requirements)
  if assertion_count_valid then
    result.requirements_met = result.requirements_met + 1
  else
    result.passes = false
    if assertion_count_issue then
      table.insert(result.issues, assertion_count_issue)
    end
  end
  
  -- 2. Check assertion types
  local assertion_types_valid, assertion_types_issue = M.check_assertion_types(test_info, requirements)
  if assertion_types_valid then
    result.requirements_met = result.requirements_met + 1
  else
    result.passes = false
    if assertion_types_issue then
      table.insert(result.issues, assertion_types_issue)
    end
  end
  
  -- 3. Check organization requirements
  local organization_valid, organization_issues = M.check_organization(test_info, requirements)
  if organization_valid then
    result.requirements_met = result.requirements_met + 1
  else
    result.passes = false
    -- Add all organization issues
    if organization_issues then
      for _, issue in ipairs(organization_issues) do
        table.insert(result.issues, issue)
      end
    end
  end
  
  -- 4. Check coverage requirements if coverage data is available
  local coverage_valid, coverage_issue = M.check_coverage(test_info, requirements, coverage_data)
  if coverage_valid then
    result.requirements_met = result.requirements_met + 1
  else
    result.passes = false
    if coverage_issue then
      table.insert(result.issues, coverage_issue)
    end
  end
  
  -- 5. Check required patterns
  local required_patterns_valid, required_patterns_issue = M.check_required_patterns(test_info, requirements)
  if required_patterns_valid then
    result.requirements_met = result.requirements_met + 1
  else
    result.passes = false
    if required_patterns_issue then
      table.insert(result.issues, required_patterns_issue)
    end
  end
  
  -- 6. Check forbidden patterns
  local forbidden_patterns_valid, forbidden_patterns_issue = M.check_forbidden_patterns(test_info, requirements)
  if not forbidden_patterns_valid then
    result.passes = false
    if forbidden_patterns_issue then
      table.insert(result.issues, forbidden_patterns_issue)
    end
  end
  
  -- Calculate score as percentage of requirements met
  result.score = (result.requirements_met / result.total_requirements) * 100
  
  logger.debug("Evaluated test against requirements", {
    passes = result.passes,
    score = result.score,
    requirements_met = result.requirements_met,
    total_requirements = result.total_requirements,
    issues_count = #result.issues
  })
  
  return result
end

--- Get a level checker function for a specific level
---@param level number Quality level to get the checker for (1-5)
---@return function|nil checker Function that checks tests against that level, or nil if invalid level
function M.get_level_checker(level)
  if level == 1 then
    return M.evaluate_level_1
  elseif level == 2 then
    return M.evaluate_level_2
  elseif level == 3 then
    return M.evaluate_level_3
  elseif level == 4 then
    return M.evaluate_level_4
  elseif level == 5 then
    return M.evaluate_level_5
  else
    logger.warn("Invalid quality level requested", { level = level })
    return nil
  end
end

--- Get the requirements for a specific level
---@param level number Quality level (1-5)
---@return table|nil requirements Requirements table for the level, or nil if invalid level
function M.get_level_requirements(level)
  if level == 1 then
    return {
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
  elseif level == 2 then
    return {
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
  elseif level == 3 then
    return {
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
  elseif level == 4 then
    return {
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
  elseif level == 5 then
    return {
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
        require_coverage_threshold = 90,
        require_performance_tests = true,
        require_security_tests = true
      },
      required_patterns = {"should", "when", "boundary", "security", "performance"},
      forbidden_patterns = {"SKIP", "TODO", "FIXME"},
    }
  else
    logger.warn("Invalid quality level requested", { level = level })
    return nil
  end
end

-- Return the module
return M
