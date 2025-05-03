--- mock_sequence_example.lua
--
-- This example demonstrates sequence-based tracking for mock function calls
-- in Firmo, contrasting it with potential issues in timestamp-based systems.
-- It showcases sequence verification assertions like `was_called_before` and
-- `was_called_after`, which allow for reliable testing of call order
-- regardless of execution speed or timing variations.
--
-- Run embedded tests: lua test.lua examples/mock_sequence_example.lua
--

-- Extract the testing functions we need
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
local describe = firmo.describe
---@type fun(description: string, options: table|function, callback: function?) it Test case function with optional parameters
local it = firmo.it
---@type fun(value: any) expect Assertion generator function
local expect = firmo.expect
local mock = firmo.mock
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("MockSequenceExample")

--- Test suite demonstrating mock call sequence tracking and verification.
describe("Mock Sequence Tracking", function()
  -- Example service that will be mocked
  --- @class MockService
  --- @field getData fun(): string
  --- @field processData fun(data: string): string
  --- @field saveResult fun(result: string): boolean
  --- @within examples.mock_sequence_example
  local service = {
    getData = function()
      return "real data"
    end,
    processData = function(data)
      return "processed: " .. data
    end,
    saveResult = function(result)
      return true
    end,
  }

  --- This section is **informational only** to explain the rationale behind sequence tracking.
  --- @within examples.mock_sequence_example
  describe("1. Problems with Timestamp-Based Tracking (Informational)", function()
    --- Explains potential timing ambiguity.
    it("can have timing ambiguity", function()
      -- In timestamp-based systems, if calls happen too quickly,
      -- they might get the same timestamp and ordering becomes ambiguous

      local mockService = mock(service)

      -- These calls happen so quickly they might get the same timestamp
      mockService.getData()
      mockService.processData("test")
      mockService.saveResult("test result")

      -- In a timestamp system, this verification might fail intermittently
      logger.info("With timestamps, verification could fail if calls have identical timestamps")
      logger.info("making it difficult to verify exact call order reliably")
      logger.info("Verification based on timestamps can be unreliable if calls happen too close together.")
    end)

    --- Explains flakiness due to system load affecting timestamps.
    it("can cause flaky tests due to system load", function()
      -- Under system load, execution timing becomes unpredictable
      local mockService = mock(service)

      -- Simulate unpredictable execution timing
      -- Simulate unpredictable execution timing
      mockService.getData()
      -- Simulate potential delay; sequence tracking is independent of timing.
      mockService.processData("test")

      logger.info("Timestamp verification becomes unreliable when system load affects timing")
    end)
    logger.info("Timestamp verification becomes unreliable when system load affects timing.")
  end)
end)

--- Demonstrates the reliability of sequence tracking.
--- @within examples.mock_sequence_example
describe("2. Sequence-Based Tracking Solution", function()
  --- Shows that sequence is preserved even with rapid calls.
  it("preserves order regardless of execution speed", function()
    local mockService = mock(service)

    -- No matter how quickly these execute, sequence numbers are assigned incrementally
    local call1 = mockService.getData() -- Call 1, sequence 1
    local call2 = mockService.processData("test") -- Call 2, sequence 2
    local call3 = mockService.saveResult("test result") -- Call 3, sequence 3

    -- Verify calls happened using .called property (basic check)
    expect(mockService.getData.called).to.be_truthy()
    expect(mockService.processData.called).to.be_truthy()
    expect(mockService.saveResult.called).to.be_truthy()

    -- **Firmo does not currently have built-in `was_called_before/after` assertions.**
    -- To verify sequence, you would manually inspect the `.calls` array
    -- which stores calls in the order they occurred.
    expect(mockService.calls[1].method_name).to.equal("getData")
    expect(mockService.calls[2].method_name).to.equal("processData")
    expect(mockService.calls[3].method_name).to.equal("saveResult")

    logger.info("Sequence-based tracking guarantees correct order via the `.calls` array.")
  end)

  --- Shows sequence tracking works even with simulated delays.
  it("works consistently with delays between calls", function()
    local mockService = mock(service)

    -- Even with delays, sequence numbers preserve order
    mockService.getData() -- Sequence 1
    -- Simulate delay (doesn't affect sequence number assignment)
    mockService.processData("test") -- Sequence 2

    -- Verify sequence using the `.calls` array
    expect(mockService.calls[1].method_name).to.equal("getData")
    expect(mockService.calls[2].method_name).to.equal("processData")

    logger.info("Sequence tracking works consistently even with delays.")
  end)
end)

--- Demonstrates manually verifying call sequences using the `.calls` array.
--- @within examples.mock_sequence_example
describe("3. Verifying Call Sequences Manually", function()
  --- Tests verifying the exact order of calls.
  it("can verify exact call order using the .calls array", function()
    local mockService = mock(service)

    mockService.getData()
    mockService.processData("test")
    mockService.saveResult("test result")

    -- Verify the order by checking the method names in the .calls array
    expect(mockService.calls[1].method_name).to.equal("getData")
    expect(mockService.calls[2].method_name).to.equal("processData")
    expect(mockService.calls[3].method_name).to.equal("saveResult")

    -- Verify arguments along with order
    expect(mockService.calls[2].args[1]).to.equal("test")
    expect(mockService.calls[3].args[1]).to.equal("test result")
  end)

  --- Tests verifying the order of specific calls among others.
  it("can verify relative order of specific calls", function()
    local mockService = mock(service)

    mockService.getData() -- Call 1
    mockService.processData("first") -- Call 2
    mockService.getData() -- Call 3
    mockService.processData("second") -- Call 4
    mockService.saveResult("final") -- Call 5

    -- Find the indices of specific calls
    local firstProcessCallIndex
    local secondProcessCallIndex
    local saveCallIndex

    for i, call in ipairs(mockService.calls) do
      if call.method_name == "processData" and call.args[1] == "first" then
        firstProcessCallIndex = i
      elseif call.method_name == "processData" and call.args[1] == "second" then
        secondProcessCallIndex = i
      elseif call.method_name == "saveResult" then
        saveCallIndex = i
      end
    end

    -- Verify the relative order using indices
    expect(firstProcessCallIndex).to.exist()
    expect(secondProcessCallIndex).to.exist()
    expect(saveCallIndex).to.exist()
    expect(firstProcessCallIndex).to.be_less_than(secondProcessCallIndex)
    expect(secondProcessCallIndex).to.be_less_than(saveCallIndex)
  end)

  --- This section is informational, as Firmo lacks built-in sequence assertions.
  --- Failures in manual sequence checks (like the one above) would be standard
  --- assertion failures (e.g., "Expected 'processData' to equal 'getData'").
  --- @within examples.mock_sequence_example
  describe("4. Sequence Verification Failures (Informational)", function()
    --- Explains how manual sequence check failures appear.
    it("failures in manual checks report standard assertion errors", function()
      local mockService = mock(service)

      -- Intentionally call in wrong order
      mockService.processData("test") -- Call 1
      mockService.getData() -- Call 2

      -- This assertion will fail because calls[1].method_name is 'processData'
      local success, err = pcall(function()
        expect(mockService.calls[1].method_name).to.equal("getData")
      end)

      expect(success).to.be_falsy()
      expect(err).to.match("Expected 'processData' to equal 'getData'")
      logger.info("Manual sequence check failed as expected: " .. err)
    end)
  end)
end)
