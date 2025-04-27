--- LPegLabel Module Tests
---
--- This test suite verifies the basic functionality of the loaded LPegLabel module
--- (`lib.tools.vendor.lpeglabel`), a labeled variant of LPeg used by the Firmo parser.
---
--- The tests ensure:
--- - Successful module loading and initialization.
--- - Availability of core LPeg functions (`P`, `V`, `C`, `Ct`).
--- - Presence of a version identifier (`version`).
--- - Basic pattern matching (`P`, `^`).
--- - Basic captures (`C`, `Ct`).
--- - Basic grammar definition and usage (`P({...})`).
--- - Support for labeled failures (`T`).
--- Uses a `before` hook to load the module safely via `pcall`.
---
--- @author Firmo Team
--- @test

local firmo = require("firmo")

local test_helper = require("lib.tools.test_helper")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

describe("LPegLabel Module", function()
  local lpeglabel

  before(function()
    -- Load LPegLabel module
    local success, result = pcall(function()
      return require("lib.tools.vendor.lpeglabel")
    end)

    expect(success).to.be_truthy("LPegLabel module failed to load")
    lpeglabel = result
  end)

  it("should provide core LPeg functionality", function()
    expect(lpeglabel).to.be.a("table")
    expect(lpeglabel.P).to.be.a("function")
    expect(lpeglabel.V).to.be.a("function")
    expect(lpeglabel.C).to.be.a("function")
    expect(lpeglabel.Ct).to.be.a("function")
  end)

  it("should have a version", function()
    local version = type(lpeglabel.version) == "function" and lpeglabel.version() or lpeglabel.version
    expect(version).to.exist()
  end)

  describe("Basic Pattern Matching", function()
    it("should match simple patterns", function()
      local P = lpeglabel.P

      -- Basic pattern matching
      local digit = P("1")
      expect(digit:match("1")).to.equal(2) -- Returns position after match
      expect(digit:match("2")).to.equal(nil) -- No match

      -- Repetition
      local digits = P("1") ^ 1 -- One or more 1's
      expect(digits:match("111")).to.equal(4)
      expect(digits:match("1112")).to.equal(4)
      expect(digits:match("abc")).to.equal(nil)
    end)

    it("should support captures", function()
      local P, C, Ct = lpeglabel.P, lpeglabel.C, lpeglabel.Ct

      -- Simple capture
      local cap = C(P("a") ^ 1)
      expect(cap:match("aaa")).to.equal("aaa")

      -- Table capture
      local tcap = Ct(C(P("a") ^ 1) * P(",") * C(P("b") ^ 1))
      local result = tcap:match("aaa,bbb")

      expect(result).to.be.a("table")
      expect(#result).to.equal(2)
      expect(result[1]).to.equal("aaa")
      expect(result[2]).to.equal("bbb")
    end)
  end)

  describe("Grammars", function()
    it("should support grammar definitions", function()
      local P, V, C, Ct = lpeglabel.P, lpeglabel.V, lpeglabel.C, lpeglabel.Ct

      -- Simple grammar
      local grammar = P({
        "S",
        S = Ct(C(P("a") ^ 1) * P(",") * C(P("b") ^ 1)),
      })

      local result = grammar:match("aaa,bbb")
      expect(result).to.be.a("table")
      expect(#result).to.equal(2)
      expect(result[1]).to.equal("aaa")
      expect(result[2]).to.equal("bbb")
    end)
  end)

  describe("Error Labels", function()
    it("should support error labels", function()
      local P, V, T = lpeglabel.P, lpeglabel.V, lpeglabel.T

      -- Grammar with labels using core API
      local g = P({
        "S",
        S = V("A") * V("B"),
        A = P("a") + T("ErrA"),
        B = P("b") + T("ErrB"),
      })

      -- Successful match
      local r1, l1, p1 = g:match("ab")
      expect(r1).to.equal(3) -- Position after match
      expect(l1).to.equal(nil) -- No error label

      -- Error in rule A
      local r2, l2, p2 = g:match("xb")
      expect(r2).to.equal(nil) -- Match failed
      expect(l2).to.equal("ErrA") -- Error label from rule A
    end)
  end)
end)
