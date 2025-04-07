# Environment Variable Configuration for Coverage v3

This document describes how to configure the coverage system using environment variables, which is particularly useful for CI/CD environments and scripted workflows.

## Environment Variable Support

The v3 coverage system provides comprehensive environment variable support for all configuration options. Environment variables take precedence over configuration files, allowing for easy overrides in different environments.

## Core Configuration Variables

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `FIRMO_COVERAGE_ENABLED` | `false` | Enable/disable coverage tracking (`true` or `false`) |
| `FIRMO_COVERAGE_DEBUG` | `false` | Enable debug mode for verbose logging (`true` or `false`) |
| `FIRMO_COVERAGE_VERSION` | `3` | Coverage version to use (`2` for legacy, `3` for new) |
| `FIRMO_COVERAGE_CACHE_ENABLED` | `true` | Enable caching of instrumented modules (`true` or `false`) |
| `FIRMO_COVERAGE_CACHE_DIR` | `./.firmo-cache` | Directory for caching instrumented modules |

## Inclusion/Exclusion Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `FIRMO_COVERAGE_INCLUDE` | `.*%.lua$` | Regex pattern for files to include |
| `FIRMO_COVERAGE_EXCLUDE` | `.*test.*%.lua$` | Regex pattern for files to exclude |
| `FIRMO_COVERAGE_INCLUDE_LIST` | (none) | Comma-separated list of specific files to include |
| `FIRMO_COVERAGE_EXCLUDE_LIST` | (none) | Comma-separated list of specific files to exclude |

## Instrumentation Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `FIRMO_COVERAGE_PRESERVE_COMMENTS` | `true` | Preserve comments in instrumented code (`true` or `false`) |
| `FIRMO_COVERAGE_PRESERVE_WHITESPACE` | `true` | Preserve whitespace in instrumented code (`true` or `false`) |
| `FIRMO_COVERAGE_TRACK_FUNCTION_CALLS` | `false` | Track function call coverage (`true` or `false`) |
| `FIRMO_COVERAGE_TRACK_BRANCHES` | `false` | Track branch coverage (`true` or `false`) |

## Reporting Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `FIRMO_COVERAGE_REPORT_FORMAT` | `html` | Default report format (`html`, `json`, `lcov`, etc.) |
| `FIRMO_COVERAGE_REPORT_DIR` | `./coverage-reports` | Directory for coverage reports |
| `FIRMO_COVERAGE_REPORT_TITLE` | `Coverage Report` | Title for the coverage report |
| `FIRMO_COVERAGE_COLOR_COVERED` | `#00FF00` | Color for covered lines (green) |
| `FIRMO_COVERAGE_COLOR_EXECUTED` | `#FFA500` | Color for executed lines (orange) |
| `FIRMO_COVERAGE_COLOR_UNCOVERED` | `#FF0000` | Color for uncovered lines (red) |

## Example Usage

### Basic Configuration

```bash
# Enable coverage in CI environment
export FIRMO_COVERAGE_ENABLED=true
export FIRMO_COVERAGE_REPORT_DIR=/tmp/coverage-reports
lua test.lua --coverage tests/
```

### Configuring Inclusion/Exclusion

```bash
# Include only specific modules
export FIRMO_COVERAGE_INCLUDE=".*lib/core/.*%.lua$"
export FIRMO_COVERAGE_EXCLUDE=".*lib/core/deprecated/.*%.lua$"

# Or use lists for specific files
export FIRMO_COVERAGE_INCLUDE_LIST="lib/core/config.lua,lib/core/version.lua"
```

### Customizing Reports

```bash
# Generate both HTML and JSON reports
export FIRMO_COVERAGE_REPORT_FORMAT="html,json"
export FIRMO_COVERAGE_REPORT_TITLE="Sprint 23 Coverage Report"

# Customize colors
export FIRMO_COVERAGE_COLOR_COVERED="#00CC00"
export FIRMO_COVERAGE_COLOR_EXECUTED="#FFCC00"
export FIRMO_COVERAGE_COLOR_UNCOVERED="#CC0000"
```

### Debug and Diagnostics

```bash
# Enable debug mode for troubleshooting
export FIRMO_COVERAGE_DEBUG=true
export FIRMO_COVERAGE_CACHE_ENABLED=false  # Disable caching for diagnosis
```

## Integration with CI/CD Systems

### GitHub Actions

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Lua
        uses: leafo/gh-actions-lua@v8
      
      - name: Run tests with coverage
        env:
          FIRMO_COVERAGE_ENABLED: true
          FIRMO_COVERAGE_REPORT_FORMAT: html,json
          FIRMO_COVERAGE_REPORT_DIR: ./coverage-reports
        run: lua test.lua --coverage tests/
      
      - name: Upload coverage reports
        uses: actions/upload-artifact@v2
        with:
          name: coverage-reports
          path: ./coverage-reports
```

### GitLab CI

```yaml
test:
  stage: test
  script:
    - export FIRMO_COVERAGE_ENABLED=true
    - export FIRMO_COVERAGE_REPORT_FORMAT=html,json,cobertura
    - export FIRMO_COVERAGE_REPORT_DIR=./coverage-reports
    - lua test.lua --coverage tests/
  artifacts:
    paths:
      - ./coverage-reports
```

### Jenkins

```groovy
pipeline {
    agent any
    stages {
        stage('Test') {
            steps {
                sh '''
                    export FIRMO_COVERAGE_ENABLED=true
                    export FIRMO_COVERAGE_REPORT_FORMAT=html
                    export FIRMO_COVERAGE_REPORT_DIR=./coverage-reports
                    lua test.lua --coverage tests/
                '''
            }
        }
    }
    post {
        always {
            publishHTML([
                allowMissing: false,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'coverage-reports',
                reportFiles: 'index.html',
                reportName: 'Coverage Report'
            ])
        }
    }
}
```

## Environment Variable Processing

Variables are processed in this order of precedence:

1. Command-line arguments (highest priority)
2. Environment variables
3. Configuration file (.firmo-config.lua)
4. Default values (lowest priority)

## Configuration Mapping

The environment variables are mapped to the configuration structure used by the central_config system:

```lua
-- Equivalent central_config structure
local config = {
  coverage = {
    enabled = os.getenv("FIRMO_COVERAGE_ENABLED") == "true",
    debug = os.getenv("FIRMO_COVERAGE_DEBUG") == "true",
    version = tonumber(os.getenv("FIRMO_COVERAGE_VERSION") or "3"),
    cache = {
      enabled = os.getenv("FIRMO_COVERAGE_CACHE_ENABLED") ~= "false",
      dir = os.getenv("FIRMO_COVERAGE_CACHE_DIR") or "./.firmo-cache"
    },
    include = function(path)
      -- Implementation that uses FIRMO_COVERAGE_INCLUDE
    end,
    exclude = function(path)
      -- Implementation that uses FIRMO_COVERAGE_EXCLUDE
    end,
    instrumentation = {
      preserve_comments = os.getenv("FIRMO_COVERAGE_PRESERVE_COMMENTS") ~= "false",
      preserve_whitespace = os.getenv("FIRMO_COVERAGE_PRESERVE_WHITESPACE") ~= "false"
    },
    report = {
      format = os.getenv("FIRMO_COVERAGE_REPORT_FORMAT") or "html",
      dir = os.getenv("FIRMO_COVERAGE_REPORT_DIR") or "./coverage-reports",
      title = os.getenv("FIRMO_COVERAGE_REPORT_TITLE") or "Coverage Report",
      colors = {
        covered = os.getenv("FIRMO_COVERAGE_COLOR_COVERED") or "#00FF00",
        executed = os.getenv("FIRMO_COVERAGE_COLOR_EXECUTED") or "#FFA500",
        uncovered = os.getenv("FIRMO_COVERAGE_COLOR_UNCOVERED") or "#FF0000"
      }
    }
  }
}
```

## Backward Compatibility

For compatibility with v2 coverage system, the following legacy environment variables are also supported:

| Legacy Variable | New Equivalent | Notes |
|----------------|----------------|-------|
| `FIRMO_DEBUG_HOOK_ENABLED` | `FIRMO_COVERAGE_ENABLED` | Enable coverage tracking |
| `FIRMO_DEBUG_HOOK_OUTPUT_DIR` | `FIRMO_COVERAGE_REPORT_DIR` | Report output directory |
| `FIRMO_DEBUG_HOOK_FORMAT` | `FIRMO_COVERAGE_REPORT_FORMAT` | Report format |

When both legacy and new variables are set, the new variables take precedence.