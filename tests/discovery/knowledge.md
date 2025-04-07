# Discovery Knowledge

## Purpose
Test the system that finds and loads test files.

## Discovery Patterns
```lua
-- Basic pattern matching
local files = firmo.discover("tests/", "*_test.lua")

-- Recursive discovery
local all_tests = firmo.discover("tests/", "**/*_test.lua")

-- Multiple patterns
local files = firmo.discover("tests/", {
  "*_test.lua",
  "*_spec.lua"
})

-- With exclusions
local files = firmo.discover("tests/", {
  include = "*_test.lua",
  exclude = "fixtures/*"
})

-- Complex pattern matching
local files = firmo.discover("tests/", {
  include = {
    "**/*_test.lua",
    "**/*_spec.lua",
    "**/*.test.lua"
  },
  exclude = {
    "fixtures/*",
    "helpers/*",
    "node_modules/**",
    "vendor/**"
  },
  recursive = true,
  follow_symlinks = false
})
```

## Configuration
```lua
-- Via .firmo-config.lua
return {
  discovery = {
    patterns = { "*_test.lua", "*_spec.lua" },
    exclude = { "fixtures/*", "helpers/*" },
    recursive = true,
    follow_symlinks = false,
    max_depth = 10
  }
}

-- Via API
firmo.configure({
  discovery = {
    base_dir = "tests/",
    patterns = { "*_test.lua" },
    exclude = { "fixtures/*" }
  }
})

-- Dynamic configuration
local function configure_discovery()
  local config = {
    patterns = {},
    exclude = {}
  }
  
  -- Add standard patterns
  table.insert(config.patterns, "*_test.lua")
  
  -- Add CI-specific patterns
  if os.getenv("CI") then
    table.insert(config.patterns, "*_ci_test.lua")
  end
  
  return config
end
```

## Error Handling
```lua
-- Handle missing directories
local files, err = firmo.discover("nonexistent/")
if not files then
  expect(err.category).to.equal("IO")
  expect(err.message).to.match("directory not found")
end

-- Handle invalid patterns
local files, err = firmo.discover("tests/", "[invalid")
expect(err.message).to.match("invalid pattern")

-- Handle permission errors
local files, err = firmo.discover("/root/tests")
if not files then
  expect(err.category).to.equal("PERMISSION")
end
```

## Critical Rules
- Validate patterns
- Handle permissions
- Check file existence
- Clean up resources
- Document patterns

## Best Practices
- Use consistent naming
- Organize logically
- Handle nested dirs
- Exclude helpers
- Document patterns
- Test thoroughly
- Handle errors
- Clean up resources

## Performance Tips
- Cache discoveries
- Limit recursion
- Handle large dirs
- Use efficient patterns
- Monitor memory
- Clean up resources