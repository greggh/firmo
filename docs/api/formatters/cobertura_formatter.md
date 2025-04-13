# Cobertura Formatter API Reference

The Cobertura formatter generates XML coverage reports in the Cobertura format, providing detailed code coverage information compatible with many CI/CD systems and quality assessment tools.

## Overview

The Cobertura formatter produces standards-compliant XML with these key features:

- Full compliance with the Cobertura XML schema
- Hierarchical package/class organization
- Detailed line coverage information
- Function/method coverage tracking
- Branch coverage support (experimental)
- Integration with popular CI/CD tools
- Customizable structure and content
- Path manipulation for cross-platform compatibility

## Class Reference

### Inheritance

```
Formatter (Base)
  └── CoberturaFormatter
```

### Class Definition

```lua
---@class CoberturaFormatter : Formatter
---@field _VERSION string Version information
local CoberturaFormatter = Formatter.extend("cobertura", "xml")
```

## Cobertura XML Format Specification

The Cobertura formatter produces XML conforming to the Cobertura schema:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-04.dtd">
<coverage line-rate="0.75" branch-rate="0.0" lines-covered="75" lines-valid="100" branches-covered="0" branches-valid="0" complexity="0" version="1.9" timestamp="1681345678">
  <sources>
    <source>.</source>
  </sources>
  <packages>
    <package name="lib" line-rate="0.80" branch-rate="0.0" complexity="0">
      <classes>
        <class name="module" filename="lib/module.lua" line-rate="0.80" branch-rate="0.0" complexity="0">
          <methods>
            <method name="add" signature="()" line-rate="1.0" branch-rate="0.0" complexity="0">
              <lines>
                <line number="10" hits="5" branch="false"/>
                <line number="11" hits="5" branch="false"/>
                <line number="12" hits="5" branch="false"/>
              </lines>
            </method>
          </methods>
          <lines>
            <line number="1" hits="1" branch="false"/>
            <line number="3" hits="1" branch="false"/>
            <line number="10" hits="5" branch="false"/>
            <line number="11" hits="5" branch="false"/>
            <line number="12" hits="5" branch="false"/>
            <line number="15" hits="0" branch="false"/>
            <line number="16" hits="0" branch="false"/>
          </lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
```

### XML Schema Elements

- `<coverage>`: Root element with summary statistics
- `<sources>`: List of base source directories
- `<packages>`: Container for file packages (usually directories)
- `<package>`: Organization unit for related classes (typically a directory)
- `<classes>`: Container for file classes (typically Lua files)
- `<class>`: Represents a single file with coverage data
- `<methods>`: Container for method-level coverage data
- `<method>`: Coverage information for a single function
- `<lines>`: Container for line-level coverage data
- `<line>`: Individual line coverage information

## Core Methods

### format(data, options)

Formats coverage data into Cobertura XML format.

```lua
---@param data table Normalized coverage data
---@param options table|nil Formatting options
---@return string xml Cobertura XML-formatted coverage report
---@return table|nil error Error object if formatting failed
function CoberturaFormatter:format(data, options)
```

### generate(data, output_path, options)

Generate and save a complete Cobertura XML report.

```lua
---@param data table Coverage data
---@param output_path string Path to save the report
---@param options table|nil Formatting options
---@return boolean success Whether the operation succeeded
---@return string|table result Path to saved file or error object
function CoberturaFormatter:generate(data, output_path, options)
```

## Configuration Options

The Cobertura formatter supports these configuration options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `xml_version` | string | `"1.0"` | XML version declaration |
| `xml_encoding` | string | `"UTF-8"` | XML document encoding |
| `include_dtd` | boolean | `true` | Include Cobertura DTD reference |
| `pretty` | boolean | `true` | Use pretty printing with indentation |
| `sources_root` | string | `"."` | Root directory for source files |
| `base_directory` | string | `nil` | Base directory to remove from paths |
| `normalize_paths` | boolean | `true` | Normalize paths for cross-platform use |
| `path_separator` | string | `"/"` | Path separator to use in report |
| `include_methods` | boolean | `true` | Include method-level coverage information |
| `include_branches` | boolean | `false` | Include branch coverage information |
| `complexity` | boolean | `false` | Include complexity metrics (not yet implemented) |
| `version` | string | `"firmo-1.0"` | Cobertura version attribute |
| `timestamp` | number or string | `os.time()` | Timestamp (epoch seconds or formatted string) |
| `structure_style` | string | `"directory"` | Structure style (directory, namespace, flat) |
| `indent_string` | string | `"  "` | Indentation string for pretty printing |
| `min_hits` | number | `0` | Minimum hits to consider branch/line covered |
| `package_depth` | number | `1` | Number of path segments to use for package name |
| `include_source_content` | boolean | `false` | Include source code in report (non-standard) |
| `zero_fill_hits` | boolean | `false` | Include 0-hit lines for uncovered code |
| `escape_xml` | boolean | `true` | Escape XML special characters |

### Configuration Example

```lua
local reporting = require("lib.reporting")
reporting.configure_formatter("cobertura", {
  pretty = true,
  sources_root = "./src",
  base_directory = "/home/user/project",
  normalize_paths = true,
  include_methods = true,
  include_branches = false,
  structure_style = "directory",
  package_depth = 2,
  zero_fill_hits = true,
  timestamp = os.date("%Y-%m-%d %H:%M:%S")
})
```

## Coverage Data Mapping

### Package/Class Organization

The formatter organizes files hierarchically:

1. **Package Level**: Directory structures become packages
2. **Class Level**: Individual Lua files become classes
3. **Method Level**: Functions within files become methods

#### Directory Structure Style (Default)

```xml
<packages>
  <!-- lib/ directory becomes a package -->
  <package name="lib">
    <classes>
      <!-- lib/module.lua becomes a class -->
      <class name="module" filename="lib/module.lua">
        <!-- ... -->
      </class>
    </classes>
  </package>
</packages>
```

#### Namespace Style

With `structure_style = "namespace"`, paths are converted to namespaces:

```xml
<packages>
  <!-- Namespace-like structure -->
  <package name="lib.core">
    <classes>
      <class name="utils" filename="lib/core/utils.lua">
        <!-- ... -->
      </class>
    </classes>
  </package>
</packages>
```

### Line Coverage Details

Each line in the source code is mapped to a `<line>` element with:

- `number`: Line number in the source file
- `hits`: Number of times the line was executed
- `branch`: Whether the line contains a branch
- `condition-coverage`: Branch coverage percentage (if branches enabled)

```xml
<lines>
  <!-- Executed line -->
  <line number="10" hits="5" branch="false"/>
  
  <!-- Non-executed line -->
  <line number="15" hits="0" branch="false"/>
  
  <!-- Branch example -->
  <line number="20" hits="10" branch="true" condition-coverage="50% (1/2)">
    <conditions>
      <condition number="0" type="jump" coverage="50%"/>
    </conditions>
  </line>
</lines>
```

### Branch Coverage Support

Branch coverage tracks conditional logic paths:

```xml
<line number="25" hits="20" branch="true" condition-coverage="50% (1/2)">
  <conditions>
    <condition number="0" type="jump" coverage="50%"/>
  </conditions>
</line>
```

Note: Branch coverage is currently experimental in firmo. Enable with:

```lua
reporting.configure_formatter("cobertura", {
  include_branches = true
})
```

## Integration with CI Tools

### Jenkins Integration

Jenkins supports Cobertura reports through the Cobertura Plugin:

1. Install the "Cobertura Plugin" in Jenkins
2. Add a post-build action to "Publish Cobertura Coverage Report"
3. Set the report path pattern (e.g., `**/coverage-report.cobertura`)

```groovy
// Jenkinsfile
pipeline {
  agent any
  stages {
    stage('Test') {
      steps {
        sh 'lua test.lua --coverage --format=cobertura tests/'
      }
    }
  }
  post {
    always {
      cobertura coberturaReportFile: '**/coverage-report.cobertura',
                onlyStable: false,
                failNoReports: false,
                failUnhealthy: false,
                failUnstable: false,
                sourceEncoding: 'UTF-8',
                lineCoverageTargets: '80, 70, 50',
                methodCoverageTargets: '80, 70, 50',
                classCoverageTargets: '80, 70, 50'
    }
  }
}
```

### SonarQube Integration

SonarQube can import Cobertura reports:

1. Generate the Cobertura report
2. Configure SonarQube to use the report:

```properties
# sonar-project.properties
sonar.language=lua
sonar.lua.coverage.reportPaths=coverage-report.cobertura
```

Or with the scanner:

```bash
sonar-scanner \
  -Dsonar.projectKey=my-project \
  -Dsonar.sources=. \
  -Dsonar.lua.coverage.reportPaths=coverage-report.cobertura
```

### GitHub Actions Integration

```yaml
# .github/workflows/coverage.yml
name: Coverage
on: [push, pull_request]

jobs:
  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Lua
        uses: leafo/gh-actions-lua@v8
      
      - name: Run tests with coverage
        run: lua test.lua --coverage --format=cobertura tests/
      
      - name: Upload coverage report to Codecov
        uses: codecov/codecov-action@v2
        with:
          files: ./coverage-report.cobertura
          fail_ci_if_error: true
```

### GitLab CI Integration

```yaml
# .gitlab-ci.yml
test:
  script:
    - lua test.lua --coverage --format=cobertura tests/
  artifacts:
    paths:
      - coverage-report.cobertura
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage-report.cobertura
```

## XML Schema Validation

The Cobertura formatter validates the generated XML against the Cobertura schema:

```lua
-- Internally, the formatter validates the output structure
local function validate_xml_structure(xml_doc)
  -- Validate root element
  if not xml_doc.name == "coverage" then
    return false, "Root element must be 'coverage'"
  end
  
  -- Validate required attributes
  local required_attrs = {"line-rate", "branch-rate", "version", "timestamp"}
  for _, attr in ipairs(required_attrs) do
    if not xml_doc.attr[attr] then
      return false, "Missing required attribute: " .. attr
    end
  end
  
  -- Validate structure
  if not xml_doc.children.sources then
    return false, "Missing required element: sources"
  end
  
  if not xml_doc.children.packages then
    return false, "Missing required element: packages"
  end
  
  -- ...additional validation...
  
  return true
end
```

To ensure schema compatibility, the formatter:

1. Follows the Cobertura XML DTD structure
2. Validates all required elements and attributes
3. Ensures correct data types for numerical values
4. Validates rate values are between 0.0 and 1.0
5. Ensures XML is well-formed

## Usage Example

```lua
local reporting = require("lib.reporting")
local coverage = require("lib.coverage")

-- Configure the Cobertura formatter
reporting.configure_formatter("cobertura", {
  pretty = true,
  sources_root = ".",
  normalize_paths = true,
  include_methods = true
})

-- Run tests with coverage
coverage.start()
-- Run tests here...
coverage.stop()

-- Generate Cobertura report
local data = coverage.get_data()
local cobertura_content = reporting.format_coverage(data, "cobertura")

-- Save the report
reporting.write_file("coverage-report.cobertura", cobertura_content)

-- Or in one step:
reporting.save_coverage_report("coverage-report.cobertura", data, "cobertura")
```

## Custom Source Directories

For projects with non-standard directory structures:

```lua
-- Specify multiple source directories
reporting.configure_formatter("cobertura", {
  sources = {
    "./src",
    "./lib",
    "./include"
  }
})
```

This produces:

```xml
<sources>
  <source>./src</source>
  <source>./lib</source>
  <source>./include</source>
</sources>
```

## Handling Non-Standard Paths

For Windows paths or other special cases:

```lua
-- Configure path normalization
reporting.configure_formatter("cobertura", {
  normalize_paths = true,              -- Convert backslashes to forward slashes
  base_directory = "C:\\Project\\src", -- Strip this prefix from paths
  path_separator = "/",                -- Use forward slashes in output
  package_depth = 2                    -- Use two directory levels for package names
})
```

## See Also

- [Cobertura Coverage Tool](https://cobertura.github.io/cobertura/)
- [Jenkins Cobertura Plugin](https://plugins.jenkins.io/cobertura/)
- [SonarQube Documentation](https://docs.sonarqube.org/latest/)
- [Reporting API](../reporting.md)
- [Coverage API](../coverage.md)
- [LCOV Formatter](./lcov_formatter.md) - Alternative coverage format

