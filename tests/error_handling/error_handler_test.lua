---@diagnostic disable: missing-parameter, param-type-mismatch
--- Error Handler Module Tests
---
--- Verifies the core functionality of the `lib.tools.error_handler` module, including:
--- - Creating structured error objects (`create`).
--- - Formatting error objects (`format_error`).
--- - Protected function calls (`try`).
--- - Specific error type creators (`validation_error`, `io_error`).
--- - Safe I/O operation wrapping (`safe_io_operation`).
--- - Assertion helper (`assert`).
--- Uses `test_helper.with_error_capture` for testing error throwing behavior.
---
--- @author Firmo Team
--- @test

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local error_handler = require("lib.tools.error_handler")

local test_helper = require("lib.tools.test_helper")

describe("Error Handler Module", function()
  it("creates structured error objects", function()
    local err = error_handler.create("Test error message", "TEST_CATEGORY", error_handler.SEVERITY.ERROR, {
      context_value = 123,
    })

    expect(err).to.exist()
    expect(err.message).to.equal("Test error message")
    expect(err.category).to.equal("TEST_CATEGORY")
    expect(err.context).to.exist()
    expect(err.context.context_value).to.equal(123)
  end)

  it("formats errors correctly", function()
    local err = error_handler.create("Test error", "TEST", error_handler.SEVERITY.ERROR, { param = "value" })
    local formatted = error_handler.format_error(err)

    expect(formatted).to.be.a("string")
    expect(formatted).to.match("Test error")
    expect(formatted).to.match("TEST")
    expect(formatted).to.match("param")
    expect(formatted).to.match("value")
  end)

  it("provides a try function for protected calls", { expect_error = true }, function()
    local success, result, err = error_handler.try(function()
      return "success"
    end)

    expect(success).to.be_truthy()
    expect(result).to.equal("success")
    expect(err).to_not.exist()

    -- Test error case
    local error_success, error_result, error_err = error_handler.try(function()
      error("Test error")
    end)

    expect(error_success).to_not.be_truthy()
    expect(error_result).to.exist() -- Contains the error
    expect(error_result).to.match("Test error") -- Verify the error message
    expect(error_err).to_not.exist() -- No third return value in error case
  end)

  it("creates validation errors", function()
    local err = error_handler.validation_error("Invalid value", {
      parameter = "test_param",
      expected = "string",
      actual = "number",
    })

    expect(err).to.exist()
    expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
    expect(err.message).to.equal("Invalid value")
    expect(err.context.parameter).to.equal("test_param")
  end)

  it("creates IO errors", function()
    local err = error_handler.io_error("File not found", {
      path = "/path/to/file",
      operation = "read",
    })

    expect(err).to.exist()
    expect(err.category).to.equal(error_handler.CATEGORY.IO)
    expect(err.message).to.equal("File not found")
    expect(err.context.path).to.equal("/path/to/file")
    expect(err.context.operation).to.equal("read")
  end)

  it("runs safe IO operations", { expect_error = true }, function()
    local result, err = error_handler.safe_io_operation(function()
      return "file content"
    end, "/path/to/file", { operation = "read" })

    expect(result).to.equal("file content")
    expect(err).to_not.exist()

    -- Test error case
    local error_result, error_err = error_handler.safe_io_operation(function()
      error("IO Error")
    end, "/path/to/file", { operation = "read" })

    expect(error_result).to_not.exist()
    expect(error_err).to.exist()
    expect(error_err.category).to.equal(error_handler.CATEGORY.IO)
    expect(error_err.context.path).to.equal("/path/to/file")
  end)

  it("supports assert with custom error category", { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      error_handler.assert(false, "Assertion failed", "CUSTOM_CATEGORY", { test = true })
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.equal("Assertion failed")
    expect(err.category).to.equal("CUSTOM_CATEGORY")
    expect(err.context.test).to.equal(true)
  end)
end)
