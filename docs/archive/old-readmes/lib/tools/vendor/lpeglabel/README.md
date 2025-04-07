# LPegLabel Integration for lust-next

This is a bundled version of LPegLabel, a parsing library that extends LPeg with labeled failures. It's used by the Lua parser module to provide better error messages and more accurate parsing.

## Features

- Build-on-first-use mechanism for automatic compilation
- Fallback to a limited pure Lua implementation when compilation is not possible
- Cross-platform support (Linux, macOS, Windows)
- Clean integration with detailed error logging

## Original Project

- **Source**: https://github.com/sqmedeiros/lpeglabel
- **License**: MIT (see LICENSE file)
- **Version**: 1.6.1

## Usage

To use this module:

```lua
local lpeg = require("lib.tools.vendor.lpeglabel")
local P, V, C, Ct = lpeg.P, lpeg.V, lpeg.C, lpeg.Ct

-- Simple grammar test
local grammar = P{
  "S";
  S = Ct(C(P"a"^1) * P"," * C(P"b"^1))
}

local result = grammar:match("aaa,bbb")
```

## How it Works

1. When the module is first required, it checks for an existing compiled binary
2. If no binary exists, it attempts to compile the C source code automatically
3. If compilation succeeds, it loads the binary
4. If compilation fails, it falls back to a limited pure Lua implementation

## Build Log

Build logs are stored in `build.log` in the same directory as the module.

## Manual Compilation

To manually compile the module:

```bash
cd lib/tools/vendor/lpeglabel
make linux    # For Linux
make macosx   # For macOS
make windows  # For Windows
```

## Credits

This integration includes code from the LPegLabel project by Sérgio Medeiros, Roberto Ierusalimschy, and Fabio Mascarenhas.