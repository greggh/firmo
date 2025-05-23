# Code Coverage Guide

This guide explains how to use Firmo's code coverage features to identify which parts of your code are being exercised by your tests.

## Introduction


Code coverage is a measure of how much of your source code is executed when your tests run. It helps you:


- Identify untested code sections
- Understand test effectiveness
- Ensure critical paths are tested
- Monitor coverage trends

Firmo provides a robust coverage system using LuaCov's debug hook mechanism that tracks:


- Line execution (which lines of code were run)
- Line hits (how many times each line executed)
- Coverage statistics (percentages and summaries)

The system integrates seamlessly with LuaCov's battle-tested coverage tracking while adding firmo's robust file handling, error management, and reporting capabilities.

## Basic Usage


### Running Tests with Coverage


Enable coverage through the command line:


```bash
lua firmo.lua --coverage tests/
```


This will:


1. Initialize the debug hook system
2. Track all executed lines during test runs
3. Generate coverage reports when complete


### Generating Coverage Reports


Specify report formats:


```bash

# Generate HTML report (rich visualization)


lua firmo.lua --coverage --format html tests/

# Generate JSON report (machine-readable)


lua firmo.lua --coverage --format json tests/

# Generate LCOV report (CI integration)


lua firmo.lua --coverage --format lcov tests/
```



### Viewing Coverage Reports


The HTML report provides the most detailed view:


1. Open `coverage-reports/coverage-report.html` in a browser
2. Navigate through your project's files
3. View line-by-line execution data with hit counts
4. See overall statistics and summaries


## Understanding Coverage Data


Firmo's coverage tracking provides:


1. **Line Execution**: Whether a line was executed
2. **Hit Counts**: How many times each line ran
3. **Coverage Statistics**: 
   - Total lines in file
   - Lines executed
   - Coverage percentage
   - Hit counts distribution


## Configuring Coverage


### Command Line Options


| Option | Description |
|--------|-------------|
| `--coverage` | Enable coverage tracking |
| `--format FORMAT` | Set report format (html, json, lcov, summary) |
| `--output-file FILE` | Specify output file for report |
| `--include PATTERNS` | Comma-separated patterns of files to include |
| `--exclude PATTERNS` | Comma-separated patterns of files to exclude |
| `--threshold PERCENT` | Minimum coverage percentage to require |

### Through Central Configuration


You can also configure coverage through the central configuration system:


```lua
local central_config = require("lib.core.central_config")
central_config.set("coverage", {
  include = function(file_path)
    return file_path:match("^src/") ~= nil
  end,
  exclude = function(file_path)
    return file_path:match("^src/vendor/") ~= nil
  end,
  track_all_executed = true,
  threshold = 80,
  output_dir = "./coverage-reports"
})
```



## Include and Exclude Patterns


Coverage tracking can be focused on specific code by including or excluding files:

### Include Patterns


Include patterns determine which files to track:


```bash

# Only track files in the src directory


lua firmo.lua --coverage --include "src/**/*.lua" tests/
```



### Exclude Patterns


Exclude patterns determine which files to ignore:


```bash

# Ignore vendor files


lua firmo.lua --coverage --exclude "src/vendor/**/*.lua" tests/
```



### Combining Patterns


You can combine include and exclude patterns:


```bash

# Track src files except for vendor files


lua firmo.lua --coverage --include "src/**/*.lua" --exclude "src/vendor/**/*.lua" tests/
```



## Coverage Thresholds


Set minimum coverage requirements:


```bash

# Require at least 80% coverage


lua firmo.lua --coverage --threshold 80 tests/
```


When a threshold is set, the test run will fail if coverage falls below that percentage.

## Integrating with CI Systems


Coverage reports can be integrated into CI workflows:


```yaml

# GitHub Actions example


jobs:
  test:
    runs-on: ubuntu-latest
    steps:


      - uses: actions/checkout@v2
      - name: Run tests with coverage

        run: lua firmo.lua --coverage --format lcov tests/


      - name: Upload coverage report

        uses: coverallsapp/github-action@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          path-to-lcov: ./coverage-reports/coverage-report.lcov
```



## Best Practices


### Coverage Goals



1. **Start with achievable goals**: Begin with a modest target (e.g., 70%)
2. **Increase coverage gradually**: Incrementally raise your threshold as coverage improves
3. **Focus on critical code**: Prioritize coverage of core functionality and error-prone code


### Test Quality



1. **Coverage isn't everything**: High coverage with weak assertions can miss bugs
2. **Assertions matter**: Use `expect` assertions to actually verify results
3. **Combine with quality metrics**: Use Firmo's `--quality` flag alongside coverage


### File Organization



1. **Group related code**: Group related functionality to make coverage patterns easier
2. **Consistent file locations**: Use consistent directory structures
3. **Separate test utilities**: Put test helpers outside of core code to avoid skewing metrics


## Advanced Usage


### Programmatic Access


You can access coverage data programmatically:


```lua
local central_config = require("lib.core.central_config")
local coverage = require("lib.coverage")
-- Configure coverage
central_config.set("coverage.include", function(file_path)
  return file_path:match("^src/") ~= nil
end)
-- Start coverage
coverage.start()
-- Run your code/tests here
-- ...
-- Stop coverage and get data
coverage.stop()
local data = coverage.get_data()
-- Process coverage data
for file_path, file_data in pairs(data.files) do
  print(string.format("File: %s - %.2f%% covered", 
    file_path, file_data.percentage or 0))
end
```



### Custom Reporting


You can create custom coverage reports:


```lua
local coverage = require("lib.coverage")
local reporting = require("lib.reporting")
-- Customize HTML report options
reporting.configure_formatter("html", {
  theme = "dark",
  show_line_numbers = true,
  include_source = true,
  collapsible_sections = true
})
-- Generate the report
reporting.generate_coverage_report("html", "./coverage-reports/custom-report.html")
```



## Debug Hook Coverage System


Firmo uses LuaCov's proven debug hook system for coverage tracking, which offers several advantages:

### Features



1. **Reliable Tracking**
   - Uses Lua's built-in debug hooks
   - No code modification required
   - Accurate line execution tracking
   - Support for all Lua versions
2. **Thread Support**
   - Automatic coroutine handling
   - Per-thread coverage tracking
   - Safe concurrent operation
   - Clean thread cleanup
3. **Performance**
   - Minimal runtime overhead
   - Efficient hit counting
   - Optimized file I/O
   - Smart stats buffering


### Considerations



1. **Code Loading**
   - By default, only tracks files loaded from disk
   - Can optionally track code loaded from strings
   - Configure via `codefromstrings` setting
2. **Coroutines**
   - Automatically patches coroutine.create
   - Handles coroutine.wrap properly
   - Maintains consistent tracking across threads
   - Some overhead for thread management
3. **Memory Usage**
   - Keeps hit counts in memory
   - Regular stats file updates
   - Configurable save frequency
   - Clean memory management


## Troubleshooting


### Low Coverage Issues


If you have unexpectedly low coverage:


1. **Check include/exclude patterns**: Ensure your patterns match the expected files
2. **Check file paths**: Different paths may cause files to be missed
3. **Look for dead code**: Unreachable code won't be covered
4. **Check test execution**: Ensure all your tests are running


### Report Problems


If your coverage reports don't look right:


1. **Check file paths**: Ensure paths are consistent between tracking and reporting
2. **Verify central configuration**: Check your central_config settings
3. **Look for conflicts**: Other debug hooks might interfere with coverage


## Understanding Report Data


### HTML Report Structure


The HTML report contains:


1. **Summary page**: Overall statistics and file listing
2. **File views**: Line-by-line coverage visualization with hit counts
3. **Legend**: Color key showing execution frequency
4. **Navigation**: File tree navigation


### Coverage Metrics


Important metrics in reports:


1. **Line coverage**: Percentage of lines executed
2. **Hit counts**: How many times each line ran
3. **File coverage**: Percentage of files with any coverage
4. **Overall coverage**: Weighted average across all files


## Best Practices for Debug Hook Coverage



1. **Initialize/Shutdown Properly**

   ```lua
   -- Always initialize before coverage tracking
   coverage.init()

   -- Clean up after testing
   coverage.shutdown()
   ```


2. **Thread Safety**

   ```lua
   -- Safe coroutine usage
   local co = coroutine.create(function()
     -- Coverage automatically tracked
     my_function()
   end)
   ```


3. **Performance Optimization**

   ```lua
   -- For long-running tests
   central_config.set("coverage", {
     tick = true,          -- Enable tick-based saving
     savestepsize = 1000,  -- Increase save interval
   })
   ```


4. **Regular Stats Saving**

   ```lua
   -- For large test suites, save periodically
   after(function()
     coverage.save_stats()
   end)
   ```

## Conclusion


Firmo's debug hook coverage system provides deep insight into test effectiveness. By regularly tracking coverage and working to improve it, you can build more reliable code with fewer defects.
Remember that coverage is just one aspect of test quality. Combine it with thoughtful test design, effective assertions, and good development practices for the best results.
For practical examples, see the [coverage examples](/examples/coverage_examples.md) file.
