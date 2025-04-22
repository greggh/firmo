# JUnit Formatter API Reference


The JUnit formatter produces XML reports in JUnit format, providing test and coverage results compatible with CI/CD systems, test runners, and reporting tools that support the JUnit XML standard.

## Overview


The JUnit formatter generates reports with these key features:


- Full compliance with JUnit XML schema
- Seamless integration with CI/CD systems (Jenkins, GitHub Actions, GitLab CI)
- Test result mapping with detailed information
- Coverage data integration as custom properties
- Comprehensive error and failure reporting
- Support for skipped and pending tests
- Hierarchical test suite organization
- Custom attribute support for extended information


## Class Reference


### Inheritance



```text
Formatter (Base)
  └── JUnitFormatter
```



### Class Definition



```lua
---@class JUnitFormatter : Formatter
---@field _VERSION string Version information
local JUnitFormatter = Formatter.extend("junit", "xml")
```



## JUnit XML Format Specification


The JUnit formatter produces XML conforming to the JUnit XML schema:


```xml
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="AllTests" tests="4" failures="1" errors="0" skipped="1" time="0.12">
  <testsuite name="ModuleTests" tests="4" failures="1" errors="0" skipped="1" time="0.12">
    <properties>
      <property name="coverage.percent" value="75.5"/>
    </properties>
    <testcase name="test_function" classname="module_test" time="0.05"/>
    <testcase name="test_failure" classname="module_test" time="0.03">
      <failure message="Assertion failed" type="AssertionError">
        Expected true but got false
        at module_test.lua:25
      </failure>
    </testcase>
    <testcase name="test_error" classname="module_test" time="0.04">
      <error message="Runtime error" type="RuntimeError">
        Attempt to call nil value
        at module_test.lua:32
      </error>
    </testcase>
    <testcase name="test_skip" classname="module_test" time="0">
      <skipped message="Not implemented yet"/>
    </testcase>
  </testsuite>
</testsuites>
```



### XML Schema Elements



- `<testsuites>`: Root element containing multiple test suites
- `<testsuite>`: Container for test cases from a single test file or module
- `<properties>`: Container for custom properties (used for coverage data)
- `<property>`: Individual name-value property for metadata
- `<testcase>`: Individual test result
- `<failure>`: Test assertion failure information
- `<error>`: Test runtime error information
- `<skipped>`: Information about skipped/pending tests
- `<system-out>`: Captured standard output (optional)
- `<system-err>`: Captured standard error (optional)


## Core Methods


### format(data, options)


Formats test results or coverage data into JUnit XML format.


```lua
---@param data table Normalized test results or coverage data
---@param options table|nil Formatting options
---@return string xml JUnit XML-formatted report
---@return table|nil error Error object if formatting failed
function JUnitFormatter:format(data, options)
```



### format_results(data, options)


Specialized method for formatting test results into JUnit XML.


```lua
---@param data table Normalized test results data
---@param options table|nil Formatting options
---@return string xml JUnit XML-formatted test results
---@return table|nil error Error object if formatting failed
function JUnitFormatter:format_results(data, options)
```



### format_coverage(data, options)


Specialized method for formatting coverage data into JUnit XML.


```lua
---@param data table Normalized coverage data
---@param options table|nil Formatting options
---@return string xml JUnit XML-formatted coverage report
---@return table|nil error Error object if formatting failed
function JUnitFormatter:format_coverage(data, options)
```



### generate(data, output_path, options)


Generate and save a complete JUnit XML report.


```lua
---@param data table Test results or coverage data
---@param output_path string Path to save the report
---@param options table|nil Formatting options
---@return boolean success Whether the operation succeeded
---@return string|table result Path to saved file or error object
function JUnitFormatter:generate(data, output_path, options)
```



## Configuration Options


The JUnit formatter supports these configuration options:
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `xml_version` | string | `"1.0"` | XML version declaration |
| `xml_encoding` | string | `"UTF-8"` | XML document encoding |
| `include_xml_decl` | boolean | `true` | Include XML declaration |
| `pretty` | boolean | `true` | Use pretty printing with indentation |
| `include_coverage` | boolean | `true` | Include coverage data as properties |
| `coverage_as_testcases` | boolean | `false` | Represent coverage as test cases |
| `suites_root_name` | string | `"AllTests"` | Name for the root testsuites element |
| `file_per_suite` | boolean | `false` | Generate separate file for each suite |
| `classname_style` | string | `"filename"` | Style for classname attribute (filename, path, fullpath) |
| `include_timestamp` | boolean | `true` | Include timestamp in report |
| `include_hostname` | boolean | `false` | Include hostname in testsuite attributes |
| `include_properties` | boolean | `true` | Include properties section |
| `include_stdio` | boolean | `false` | Include captured stdout/stderr |
| `test_naming` | string | `"hierarchical"` | Test naming scheme (flat, hierarchical) |
| `custom_attributes` | table | `{}` | Custom attributes to add to elements |
| `indent_string` | string | `"  "` | Indentation string for pretty printing |
| `prop_prefix` | string | `"coverage."` | Prefix for coverage properties |
| `newline` | string | `"\n"` | Newline character(s) |
| `escape_xml` | boolean | `true` | Escape XML special characters |
| `escape_cdata` | boolean | `true` | Escape CDATA sections |

### Configuration Example



```lua
local reporting = require("lib.reporting")
reporting.configure_formatter("junit", {
  include_coverage = true,
  coverage_as_testcases = false,
  pretty = true,
  suites_root_name = "FirmoTests",
  classname_style = "path",
  include_timestamp = true,
  include_hostname = true,
  include_properties = true,
  include_stdio = true,
  test_naming = "hierarchical"
})
```



## CI/CD System Integration


### Jenkins Integration


Jenkins natively supports JUnit XML reports:


```groovy
// Jenkinsfile
pipeline {
  agent any
  stages {
    stage('Test') {
      steps {
        sh 'lua test.lua --format=junit tests/'
      }
    }
  }
  post {
    always {
      junit '**/junit-results.xml'
    }
  }
}
```


Configure the JUnit Plugin in Jenkins:


1. Ensure the JUnit plugin is installed (usually included by default)
2. Add a post-build action to "Publish JUnit test result report"
3. Set the "Test report XMLs" field to the path of your JUnit XML files (e.g., `**/junit-results.xml`)


### GitHub Actions Integration



```yaml

# .github/workflows/test.yml


name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:


      - uses: actions/checkout@v2

      - name: Setup Lua

        uses: leafo/gh-actions-lua@v8

      - name: Run tests

        run: lua test.lua --format=junit tests/

      - name: Publish Test Report

        uses: mikepenz/action-junit-report@v2
        if: always() # always run even if tests fail
        with:
          report_paths: '**/junit-results.xml'
          fail_on_failure: true
          require_tests: true
```



### GitLab CI Integration



```yaml

# .gitlab-ci.yml


test:
  script:


    - lua test.lua --format=junit tests/

  artifacts:
    when: always
    reports:
      junit: junit-results.xml
```



### Azure DevOps Integration



```yaml

# azure-pipelines.yml


steps:


- script: lua test.lua --format=junit tests/

  displayName: 'Run Tests'


- task: PublishTestResults@2

  inputs:
    testResultsFormat: 'JUnit'
    testResultsFiles: '**/junit-results.xml'
    mergeTestResults: true
    testRunTitle: 'Lua Tests'
  condition: succeededOrFailed()
```



### Circle CI Integration



```yaml

# .circleci/config.yml


version: 2.1
jobs:
  test:
    docker:


      - image: cimg/base:2020.01

    steps:


      - checkout
      - run:

          name: Run tests
          command: lua test.lua --format=junit tests/


      - store_test_results:

          path: ./junit-results.xml
```



## Test Result Mapping


### Test Case Mapping


The JUnit formatter maps test results to XML elements:
| Test Result | XML Representation |
|-------------|-------------------|
| Passing test | `<testcase>` with no child elements |
| Failed assertion | `<testcase>` with `<failure>` child |
| Runtime error | `<testcase>` with `<error>` child |
| Skipped test | `<testcase>` with `<skipped>` child |
| Pending test | `<testcase>` with `<skipped message="Pending">` |

### Test Suite Organization


Tests are organized into suites based on their source files or modules:


```xml
<testsuites>
  <!-- Module A Tests -->
  <testsuite name="ModuleA">
    <testcase name="test_a1"/>
    <testcase name="test_a2"/>
  </testsuite>

  <!-- Module B Tests -->
  <testsuite name="ModuleB">
    <testcase name="test_b1"/>
    <testcase name="test_b2"/>
  </testsuite>
</testsuites>
```



### Hierarchical Test Names


When using `test_naming = "hierarchical"`, nested describes are represented in test names:


```xml
<testcase name="Database Connection when credentials are valid connects successfully"/>
```



## Coverage Data in JUnit Format


Coverage data can be included in JUnit reports in two ways:

### 1. As Properties (Default)



```xml
<testsuite name="AllTests">
  <properties>
    <property name="coverage.total_files" value="10"/>
    <property name="coverage.total_lines" value="500"/>
    <property name="coverage.covered_lines" value="350"/>
    <property name="coverage.coverage_percent" value="70.0"/>
    <property name="coverage.lib/module.lua.percent" value="85.0"/>
    <property name="coverage.lib/other.lua.percent" value="65.0"/>
  </properties>
  <!-- Test cases -->
</testsuite>
```



### 2. As Test Cases


When using `coverage_as_testcases = true`:


```xml
<testsuite name="Coverage">
  <!-- Overall coverage as a test case -->
  <testcase name="Overall Coverage" classname="coverage">
    <system-out>Total Files: 10, Total Lines: 500, Covered: 350 (70.0%)</system-out>
  </testcase>

  <!-- Each file as a test case - passing if above threshold -->
  <testcase name="lib/module.lua" classname="coverage">
    <system-out>Lines: 100, Covered: 85 (85.0%)</system-out>
  </testcase>

  <!-- Failed coverage appears as test failure -->
  <testcase name="lib/other.lua" classname="coverage">
    <failure message="Coverage below threshold" type="CoverageFailure">
      Expected at least 75.0% coverage, but got 65.0%
      Lines: 80, Covered: 52 (65.0%)
    </failure>
  </testcase>
</testsuite>
```



## Custom Attributes Support


Add custom attributes to XML elements:


```lua
reporting.configure_formatter("junit", {
  custom_attributes = {
    testsuites = {
      project = "Firmo",
      version = "3.0.0",
      language = "Lua"
    },
    testsuite = {
      component = function(suite) 
        return suite.name:match("^(%w+)") or "unknown"
      end
    },
    testcase = {
      priority = function(test)
        return test.metadata and test.metadata.priority or "normal"
      end
    }
  }
})
```


This produces XML with custom attributes:


```xml
<testsuites project="Firmo" version="3.0.0" language="Lua">
  <testsuite name="ModuleTests" component="Module">
    <testcase name="test_function" priority="high"/>
  </testsuite>
</testsuites>
```



## Error and Failure Handling


### Failure Representation


Test assertion failures are represented with the `<failure>` element:


```xml
<testcase name="test_equals" classname="math_test">
  <failure message="Assertion failed: values not equal" type="AssertionError">
    Expected 42 but got 41
    at math_test.lua:25 in function 'test_equals'
  </failure>
</testcase>
```



### Error Representation


Runtime errors use the `<error>` element:


```xml
<testcase name="test_division" classname="math_test">
  <error message="Runtime error: division by zero" type="RuntimeError">
    Attempt to perform division by zero
    at math_test.lua:32 in function 'test_division'
  </error>
</testcase>
```



### Stack Trace Inclusion


Stack traces can be included in error and failure messages:


```lua
reporting.configure_formatter("junit", {
  include_stack_traces = true,
  max_stack_depth = 10,
  sanitize_paths = true  -- Strip absolute paths from traces
})
```


This adds detailed stack information:


```xml
<error message="Runtime error">
  Error: attempt to call nil value
  stack traceback:
    tests/module_test.lua:32: in function 'test_function'
    lib/core/test_definition.lua:156: in function 'run_test'
    lib/core/test_runner.lua:87: in function 'run_tests'
</error>
```



## Skipped Test Support


### Simple Skipped Tests



```xml
<testcase name="test_feature" classname="feature_test">
  <skipped message="Feature not implemented yet"/>
</testcase>
```



### Pending Tests



```xml
<testcase name="test_upcoming" classname="upcoming_test">
  <skipped message="Pending: Will implement in next release"/>
</testcase>
```



### Conditional Skips



```xml
<testcase name="test_windows_only" classname="os_test">
  <skipped message="Skipped: Test only applicable on Windows"/>
</testcase>
```
