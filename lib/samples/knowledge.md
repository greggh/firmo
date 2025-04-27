# lib/samples Knowledge

## Purpose

The `lib/samples` directory contains simple, self-contained Lua modules. Their primary purpose is to serve as targets for Firmo's internal testing procedures, particularly for features like code coverage analysis. They can also function as basic demonstration examples for certain Firmo functionalities. The main example currently included is `lib/samples/calculator.lua`.

## Key Concepts

- **Simplicity:** Modules within this directory are designed to be intentionally simple and straightforward.
- **Testing Targets:** They primarily exist to be tested by Firmo itself, helping to validate core features like the test runner and coverage system.
- **Non-Core:** These modules are *not* considered part of the core Firmo framework's functionality offered to end-users. They are internal development and testing aids.

## Usage Examples / Patterns

### Using the Sample Calculator

```lua
--[[
  Demonstrates how to require and use the sample
  calculator module provided in this directory.
]]
local calculator = require("lib.samples.calculator")

local sum = calculator.add(5, 3)
-- sum will be 8
print("The sum is: " .. sum)

-- Other functions like subtract, multiply, divide are also available.
-- local difference = calculator.subtract(10, 4) -- difference is 6
-- local product = calculator.multiply(2, 6)    -- product is 12
-- local quotient = calculator.divide(9, 3)     -- quotient is 3
```

## Related Components / Modules

- **`lib/samples/calculator.lua`**: The main sample module used for demonstrating basic arithmetic and serving as a coverage target.
- **`docs/api/coverage.md`**: Documentation for Firmo's code coverage system, which often uses the modules in `lib/samples` for its own tests.
