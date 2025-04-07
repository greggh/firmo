# LPegLabel Knowledge

## Purpose
Extended LPeg parsing library with labeled failures for better error messages.

## Integration Details
```lua
-- Basic usage
local lpeg = require("lib.tools.vendor.lpeglabel")
local P, V, C, Ct = lpeg.P, lpeg.V, lpeg.C, lpeg.Ct

-- Grammar with labels
local grammar = P{
  "S";
  S = Ct(C(P"a"^1) * P"," * C(P"b"^1)) + 
      lpeg.T(ErrLabel)  -- Custom error label
}
```

## Critical Rules
- NEVER modify source files directly
- Use build-on-first-use mechanism
- Handle compilation failures gracefully
- Log build errors properly
- Clean up build artifacts

## Build Process
```bash
# Linux build
make linux

# macOS build
make macosx

# Windows build
make windows
```

## Error Handling
- Check for binary first
- Attempt compilation if needed
- Fall back to pure Lua impl
- Log build failures
- Track error labels

## Version Info
- Source: github.com/sqmedeiros/lpeglabel
- Version: 1.6.1
- License: MIT
- Authors: Sérgio Medeiros, Roberto Ierusalimschy