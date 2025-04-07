# Coverage v3 Report Format Specification

This document specifies the report formats for the v3 coverage system, focusing on the JSON format as the foundational machine-readable output that can be transformed into other formats.

## JSON Report Format

The JSON report format serves as the primary machine-readable representation of coverage data. This specification defines the schema, structure, and content of the JSON report.

### Schema

```json
{
  "$schema": "https://json-schema.org/draft-07/schema",
  "type": "object",
  "required": ["version", "metadata", "summary", "files"],
  "properties": {
    "version": {
      "type": "string",
      "description": "Version of the report format"
    },
    "metadata": {
      "type": "object",
      "description": "Metadata about the coverage run",
      "properties": {
        "timestamp": {
          "type": "integer",
          "description": "Unix timestamp when the report was generated"
        },
        "duration": {
          "type": "number",
          "description": "Duration of the coverage run in seconds"
        },
        "command": {
          "type": "string",
          "description": "Command used to run the tests"
        },
        "config": {
          "type": "object",
          "description": "Configuration used for the coverage run"
        }
      }
    },
    "summary": {
      "type": "object",
      "required": ["total_files", "total_lines", "covered_lines", "executed_lines"],
      "properties": {
        "total_files": {
          "type": "integer",
          "description": "Total number of files tracked"
        },
        "total_lines": {
          "type": "integer",
          "description": "Total number of lines in all tracked files"
        },
        "covered_lines": {
          "type": "integer",
          "description": "Number of lines that were verified by assertions"
        },
        "executed_lines": {
          "type": "integer",
          "description": "Number of lines that were executed but not verified"
        },
        "not_covered_lines": {
          "type": "integer",
          "description": "Number of lines that were not executed"
        },
        "coverage_percent": {
          "type": "number",
          "description": "Percentage of lines covered (covered / total * 100)"
        },
        "execution_percent": {
          "type": "number",
          "description": "Percentage of lines executed (executed + covered) / total * 100"
        }
      }
    },
    "files": {
      "type": "object",
      "description": "Coverage data for individual files",
      "additionalProperties": {
        "type": "object",
        "required": ["path", "summary", "lines"],
        "properties": {
          "path": {
            "type": "string",
            "description": "Path to the file"
          },
          "summary": {
            "type": "object",
            "required": ["total_lines", "covered_lines", "executed_lines"],
            "properties": {
              "total_lines": {
                "type": "integer",
                "description": "Total number of lines in the file"
              },
              "covered_lines": {
                "type": "integer",
                "description": "Number of lines verified by assertions"
              },
              "executed_lines": {
                "type": "integer",
                "description": "Number of lines executed but not verified"
              },
              "not_covered_lines": {
                "type": "integer",
                "description": "Number of lines not executed"
              },
              "coverage_percent": {
                "type": "number",
                "description": "Percentage of lines covered"
              },
              "execution_percent": {
                "type": "number",
                "description": "Percentage of lines executed"
              }
            }
          },
          "lines": {
            "type": "object",
            "description": "Data for individual lines",
            "additionalProperties": {
              "type": "object",
              "required": ["executed", "covered"],
              "properties": {
                "line_number": {
                  "type": "integer",
                  "description": "Line number in the file"
                },
                "content": {
                  "type": "string",
                  "description": "Content of the line (optional)"
                },
                "executed": {
                  "type": "boolean",
                  "description": "Whether the line was executed"
                },
                "covered": {
                  "type": "boolean",
                  "description": "Whether the line was verified by assertions"
                },
                "execution_count": {
                  "type": "integer",
                  "description": "Number of times the line was executed"
                },
                "assertions": {
                  "type": "array",
                  "description": "Assertions that verified this line",
                  "items": {
                    "type": "object",
                    "properties": {
                      "id": {
                        "type": "string",
                        "description": "Unique identifier for the assertion"
                      },
                      "file": {
                        "type": "string",
                        "description": "File containing the assertion"
                      },
                      "line": {
                        "type": "integer",
                        "description": "Line number of the assertion"
                      },
                      "text": {
                        "type": "string",
                        "description": "Text of the assertion"
                      }
                    }
                  }
                }
              }
            }
          },
          "functions": {
            "type": "object",
            "description": "Data for functions in the file (optional)",
            "additionalProperties": {
              "type": "object",
              "properties": {
                "name": {
                  "type": "string",
                  "description": "Function name"
                },
                "start_line": {
                  "type": "integer",
                  "description": "Starting line number"
                },
                "end_line": {
                  "type": "integer",
                  "description": "Ending line number"
                },
                "executed": {
                  "type": "boolean",
                  "description": "Whether the function was executed"
                },
                "covered": {
                  "type": "boolean",
                  "description": "Whether the function was verified by assertions"
                },
                "execution_count": {
                  "type": "integer",
                  "description": "Number of times the function was called"
                }
              }
            }
          },
          "branches": {
            "type": "object",
            "description": "Data for branches in the file (optional)",
            "additionalProperties": {
              "type": "object",
              "properties": {
                "line": {
                  "type": "integer",
                  "description": "Line number of the branch"
                },
                "condition": {
                  "type": "string",
                  "description": "Condition text"
                },
                "true_executed": {
                  "type": "boolean",
                  "description": "Whether the true branch was executed"
                },
                "false_executed": {
                  "type": "boolean",
                  "description": "Whether the false branch was executed"
                },
                "true_covered": {
                  "type": "boolean",
                  "description": "Whether the true branch was verified by assertions"
                },
                "false_covered": {
                  "type": "boolean",
                  "description": "Whether the false branch was verified by assertions"
                }
              }
            }
          }
        }
      }
    }
  }
}
```

### Example JSON Report

```json
{
  "version": "3.0.0",
  "metadata": {
    "timestamp": 1714567890,
    "duration": 2.45,
    "command": "lua test.lua --coverage tests/",
    "config": {
      "include": ".*%.lua$",
      "exclude": ".*test%.lua$",
      "instrumentation": {
        "preserve_comments": true
      }
    }
  },
  "summary": {
    "total_files": 3,
    "total_lines": 150,
    "covered_lines": 75,
    "executed_lines": 50,
    "not_covered_lines": 25,
    "coverage_percent": 50.0,
    "execution_percent": 83.33
  },
  "files": {
    "lib/example.lua": {
      "path": "lib/example.lua",
      "summary": {
        "total_lines": 100,
        "covered_lines": 50,
        "executed_lines": 30,
        "not_covered_lines": 20,
        "coverage_percent": 50.0,
        "execution_percent": 80.0
      },
      "lines": {
        "1": {
          "line_number": 1,
          "content": "local M = {}",
          "executed": true,
          "covered": false,
          "execution_count": 1
        },
        "2": {
          "line_number": 2,
          "content": "",
          "executed": false,
          "covered": false
        },
        "3": {
          "line_number": 3,
          "content": "function M.add(a, b)",
          "executed": true,
          "covered": false,
          "execution_count": 1
        },
        "4": {
          "line_number": 4,
          "content": "  return a + b",
          "executed": true,
          "covered": true,
          "execution_count": 3,
          "assertions": [
            {
              "id": "assertion-1",
              "file": "tests/example_test.lua",
              "line": 10,
              "text": "expect(result).to.equal(5)"
            }
          ]
        }
      },
      "functions": {
        "M.add": {
          "name": "M.add",
          "start_line": 3,
          "end_line": 5,
          "executed": true,
          "covered": true,
          "execution_count": 3
        }
      }
    }
  }
}
```

## HTML Report Format

The HTML report is a visual representation of the coverage data, designed for human readability and interaction. It is generated from the JSON report data.

### HTML Report Features

1. **Three-State Visualization**:
   - Covered lines (Green) - Verified by assertions
   - Executed lines (Orange) - Executed but not verified
   - Not covered lines (Red) - Not executed

2. **File Navigation**:
   - Directory tree view
   - File list with coverage percentages
   - Search functionality

3. **Summary Information**:
   - Overall project coverage
   - File-level summaries
   - Coverage trend (if historical data available)

4. **Line Details**:
   - Line content with syntax highlighting
   - Execution count
   - Associated assertions

5. **Filtering Options**:
   - Filter by coverage status
   - Filter by file path
   - Filter by minimum/maximum coverage

### HTML Report Structure

```
coverage-report/
├── index.html                  # Main entry point with summary
├── css/
│   ├── style.css               # Main styles
│   └── tailwind.min.css        # Tailwind CSS framework
├── js/
│   ├── report.js               # Report interaction code
│   └── alpine.min.js           # Alpine.js framework
└── files/
    ├── lib/
    │   └── example.html        # Coverage for lib/example.lua
    └── ...                     # Other file reports
```

### HTML Report Tag Colors

```css
/* Colors for coverage states */
.line-covered {
  background-color: #00FF00;  /* Green */
}

.line-executed {
  background-color: #FFA500;  /* Orange */
}

.line-not-covered {
  background-color: #FF0000;  /* Red */
}
```

## LCOV Report Format

The LCOV report format is provided for compatibility with existing tools that support the LCOV format, such as gcov, lcov, and various CI/CD platforms.

### LCOV Report Structure

```
TN:
SF:/path/to/file.lua
FN:3,M.add
FNDA:3,M.add
FNF:1
FNH:1
DA:1,1
DA:3,1
DA:4,3
LF:3
LH:3
BRF:0
BRH:0
end_of_record
```

Where:
- `TN:` - Test name
- `SF:` - Source file
- `FN:` - Function definitions (line number, function name)
- `FNDA:` - Function data (execution count, function name)
- `FNF:` - Functions found
- `FNH:` - Functions hit
- `DA:` - Line data (line number, execution count)
- `LF:` - Lines found
- `LH:` - Lines hit
- `BRF:` - Branches found
- `BRH:` - Branches hit

## Cobertura XML Report Format

The Cobertura XML format is provided for compatibility with CI/CD systems that support this format, such as Jenkins.

### Cobertura XML Structure

```xml
<?xml version="1.0" ?>
<!DOCTYPE coverage SYSTEM "https://cobertura.sourceforge.net/xml/coverage-04.dtd">
<coverage lines-valid="3" lines-covered="3" line-rate="1" branches-valid="0" branches-covered="0" branch-rate="0" timestamp="1714567890" complexity="0" version="0.1">
  <sources>
    <source>/path/to/source</source>
  </sources>
  <packages>
    <package name="lib" line-rate="1" branch-rate="0" complexity="0">
      <classes>
        <class name="example" filename="lib/example.lua" line-rate="1" branch-rate="0" complexity="0">
          <methods>
            <method name="M.add" signature="" line-rate="1" branch-rate="0" complexity="0">
              <lines>
                <line number="3" hits="1"/>
                <line number="4" hits="3"/>
              </lines>
            </method>
          </methods>
          <lines>
            <line number="1" hits="1"/>
            <line number="3" hits="1"/>
            <line number="4" hits="3"/>
          </lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
```

## Report Format Conversion

The JSON report format is the canonical representation of coverage data. Other formats are derived from the JSON format through conversion. The following conversion rules apply:

### JSON to HTML Conversion

- Each file in the JSON report gets a corresponding HTML file
- Line states are represented by CSS classes
- The directory structure is replicated in the HTML output

### JSON to LCOV Conversion

- Each file in the JSON report gets an entry in the LCOV file
- Only executed or covered lines are included in the LCOV data
- Function and branch data is included if available

### JSON to Cobertura Conversion

- The JSON structure is mapped to the Cobertura XML structure
- The three-state model is simplified to a two-state model (covered or not)
- Package and class names are derived from file paths

## Format Version Control

The report format is versioned independently of the coverage system. The current version is 3.0.0, following semantic versioning:

- Major version: Incompatible schema changes
- Minor version: Backward-compatible additions
- Patch version: Backward-compatible bug fixes

When reading reports, tools should check the version field and handle version differences appropriately.

## Third-Party Tool Integration

The JSON report format is designed to be easily consumed by third-party tools. Tools can parse the JSON data and extract the coverage information they need.

### Integration Examples

1. **Jenkins**: Use the Cobertura plugin with the Cobertura XML report
2. **GitLab**: Use the JSON or LCOV report format with the Coverage Visualization plugin
3. **SonarQube**: Use the LCOV report format with the SonarQube Scanner

## Custom Report Extensions

The JSON report format can be extended with custom data by adding new fields to the metadata object or to individual file objects. Custom extensions should follow these guidelines:

1. Use a namespace prefix to avoid conflicts with future official fields
2. Document the meaning and format of custom fields
3. Make custom extensions optional to maintain compatibility

Example custom extension:

```json
"metadata": {
  "timestamp": 1714567890,
  "custom_firmo_ci": {
    "build_id": "12345",
    "build_url": "https://ci.example.com/builds/12345",
    "custom_metrics": {
      "test_count": 150,
      "assertion_count": 350
    }
  }
}
```