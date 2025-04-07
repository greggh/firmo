# Reporting Tests

This directory contains tests for the firmo reporting system. The reporting module generates test results and coverage data in various formats.

## Directory Contents

- **enhanced_reporting_test.lua** - Tests for enhanced reporting features
- **report_validation_test.lua** - Tests for report validation functionality
- **reporting_filesystem_test.lua** - Tests for filesystem integration with reporting
- **reporting_test.lua** - Tests for core reporting functionality

### Subdirectories

- **formatters/** - Tests for specific formatters
  - **html_formatter_test.lua** - Tests for HTML report generation
  - **tap_csv_format_test.lua** - Tests for TAP and CSV format generation

## Reporting System Features

The firmo reporting system provides:

- Multiple output formats (HTML, JSON, XML, TAP, CSV)
- Coverage data visualization
- Custom formatter support
- Configurable report paths
- Report validation
- Filesystem integration for report storage
- CI/CD integration options

## Supported Formats

The reporting system supports multiple formats:

- **HTML** - Interactive reports with syntax highlighting
- **JSON** - Machine-readable data for integration
- **XML** - Standard JUnit/Cobertura XML for CI systems
- **TAP** - Test Anything Protocol for broader integration
- **CSV** - Spreadsheet-compatible test results
- **LCOV** - Standard coverage format for tools integration
- **Summary** - Concise console summary
- **Custom** - User-defined formatter support

## Running Tests

To run all reporting tests:
```
lua test.lua tests/reporting/
```

To run specific reporting tests:
```
lua test.lua tests/reporting/reporting_test.lua
```

To run formatter tests:
```
lua test.lua tests/reporting/formatters/
```

See the [Reporting API Documentation](/docs/api/reporting.md) for more information.