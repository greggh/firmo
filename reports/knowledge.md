# Reports Knowledge


## Purpose


Store and organize test and coverage reports.

## Report Organization



```lua
-- Report directory structure
local structure = {
  coverage = {
    html = "coverage/html/",
    json = "coverage/json/",
    lcov = "coverage/lcov/"
  },
  tests = {
    results = "tests/results/",
    logs = "tests/logs/"
  },
  debug = "debug/",
  archive = "archive/"
}
-- Report naming pattern
local function get_report_name(type, format)
  local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
  return string.format(
    "%s_%s.%s",
    type,
    timestamp,
    format
  )
end
```



## Critical Rules



- Clean old reports
- Organize by type
- Use consistent names
- Validate formats
- Archive properly


## Report Types



```lua
-- Coverage reports
local coverage_types = {
  html = {
    path = "coverage/html/",
    keep_days = 7
  },
  json = {
    path = "coverage/json/",
    keep_days = 30
  },
  lcov = {
    path = "coverage/lcov/",
    keep_days = 30
  }
}
-- Test results
local result_types = {
  junit = {
    path = "tests/junit/",
    keep_days = 30
  },
  tap = {
    path = "tests/tap/",
    keep_days = 30
  }
}
```



## Best Practices



- Clean regularly
- Organize by date
- Use consistent names
- Validate formats
- Archive old reports
- Monitor space
- Handle errors
- Document formats
- Test validation
- Keep organized


## Performance Tips



- Clean old files
- Compress archives
- Monitor space
- Handle large files
- Use streaming
- Batch operations
- Cache results
