# Vendor Knowledge

## Purpose
Third-party dependencies used by the framework.

## Integration Pattern
```lua
-- Safe module loading
local function load_vendor_module(name)
  local success, module = error_handler.try(function()
    return require("lib.tools.vendor." .. name)
  end)
  
  if not success then
    logger.error("Failed to load vendor module", {
      module = name,
      error = module
    })
    return nil, module
  end
  
  return module
end

-- Version compatibility check
local function check_version_compatibility(module, min_version)
  if not module.VERSION then
    return false, "No version information"
  end
  
  return semver.gte(module.VERSION, min_version)
end

-- Complex vendor integration
local function setup_vendor_module()
  -- Version locking
  local versions = {
    lpeglabel = "1.6.1",
    other_dep = "2.0.0"
  }
  
  -- Load and verify modules
  local modules = {}
  for name, required in pairs(versions) do
    -- Load module
    local module = load_vendor_module(name)
    if not module then
      return nil, string.format(
        "Failed to load %s module",
        name
      )
    end
    
    -- Check version
    local compatible = check_version_compatibility(
      module, required
    )
    if not compatible then
      return nil, string.format(
        "%s version mismatch (need %s)",
        name, required
      )
    end
    
    modules[name] = module
  end
  
  return modules
end
```

## LPegLabel Integration
```lua
-- Basic usage
local lpeg = require("lib.tools.vendor.lpeglabel")
local P, V, C, Ct = lpeg.P, lpeg.V, lpeg.C, lpeg.Ct

-- Simple grammar test
local grammar = P{
  "S";
  S = Ct(C(P"a"^1) * P"," * C(P"b"^1))
}

-- Grammar with labels
local grammar = P{
  "S";
  S = Ct(C(P"a"^1) * P"," * C(P"b"^1)) + 
      lpeg.T(ErrLabel)  -- Custom error label
}

-- Complex parsing example
local function create_parser()
  -- Define grammar
  local grammar = P{
    "Block";
    Block = V"Stmt" * (P";" * V"Stmt")^0;
    Stmt = V"Assign" + V"If" + V"While";
    Assign = C(V"Id") * P"=" * C(V"Expr");
    If = P"if" * V"Expr" * P"then" * V"Block" * P"end";
    While = P"while" * V"Expr" * P"do" * V"Block" * P"end";
    Expr = V"Term" * ((P"+" + P"-") * V"Term")^0;
    Term = V"Factor" * ((P"*" + P"/") * V"Factor")^0;
    Factor = V"Number" + V"Id" + (P"(" * V"Expr" * P")");
    Number = C(P"-"^-1 * P"0" + R"19" * R"09"^0);
    Id = C(R"az"^1)
  }
  
  return grammar
end
```

## Error Handling
```lua
-- Safe module loading
local function safe_load_vendor()
  -- Try to load binary first
  local success, module = error_handler.try(function()
    return require("lib.tools.vendor.lpeglabel")
  end)
  
  if success then
    return module
  end
  
  -- Try compilation
  success, module = error_handler.try(function()
    return compile_and_load_module()
  end)
  
  if not success then
    -- Fall back to pure Lua implementation
    return require("lib.tools.vendor.lpeglabel.fallback")
  end
  
  return module
end

-- Version verification
local function verify_versions()
  for name, required in pairs(versions) do
    local module = load_vendor_module(name)
    if not module then
      return false, "Failed to load " .. name
    end
    
    local compatible = check_version_compatibility(
      module, required
    )
    if not compatible then
      return false, name .. " version mismatch"
    end
  end
  return true
end
```

## Critical Rules
- NEVER modify vendor code
- Document all patches
- Track versions
- Test updates
- Keep minimal
- Handle errors
- Clean up state
- Monitor usage

## Best Practices
- Lock versions
- Document requirements
- Track upstream
- Test compatibility
- Update systematically
- Isolate code
- Handle conflicts
- Document deps
- Test integration
- Monitor updates

## Performance Tips
- Cache module loads
- Check versions once
- Handle failures
- Monitor updates
- Test thoroughly
- Document changes
- Profile usage
- Handle timeouts