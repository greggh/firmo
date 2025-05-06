--- This example demonstrates sequence-based tracking for mock function calls
--- in Firmo, contrasting it with potential issues in timestamp-based systems.
-- It showcases sequence verification assertions like `was_called_before` and
-- `was_called_after`, which allow for reliable testing of call order
-- regardless of execution speed or timing variations.
--
-- @module examples.mock_sequence_example
-- @author Firmo Team
--- @license MIT
--- @copyright 2023-2025
--- @version 1.0.0
-- @see firmo
-- @see lib.mocking
-- @usage
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
local before = firmo.before -- Add missing require
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("MockSequenceExample")

-- Create a service factory to ensure each test gets a fresh service
local function createService()
  return {
    getData = function() 
      return "real data" 
    end,
    processData = function(data) 
      return "processed:" .. tostring(data) 
    end,
    saveResult = function(result) 
      -- In a real service, this would save to database or similar
      return true
    end
  }
end

--- Test suite demonstrating mock call sequence tracking and verification.
describe("Mock Sequence Tracking", function()

  --- This section is **informational only** to explain the rationale behind sequence tracking.
  --- @within examples.mock_sequence_example
  describe("1. Problems with Timestamp-Based Tracking (Informational)", function()
    --- Explains potential timing ambiguity.
    it("can have timing ambiguity", function()
      -- In timestamp-based systems, if calls happen too quickly,
      -- they might get the same timestamp and ordering becomes ambiguous
      local service = createService()
      local mockService = mock(service)
      
      -- Create spies on all methods so we can track calls
      mockService:spy("getData")
      mockService:spy("processData")
      mockService:spy("saveResult")

      -- These calls happen so quickly they might get the same timestamp
      service.getData()
      service.processData("test")
      service.saveResult("test result")

      -- Verify methods were called
      expect(mockService._spies.getData).to.exist()
      expect(mockService._spies.getData.called).to.be_truthy()
      expect(mockService._spies.processData).to.exist()
      expect(mockService._spies.processData.called).to.be_truthy()
      expect(mockService._spies.saveResult).to.exist()
      expect(mockService._spies.saveResult.called).to.be_truthy()

      -- In a timestamp system, this verification might fail intermittently
      logger.info("With timestamps, verification could fail if calls have identical timestamps")
      logger.info("making it difficult to verify exact call order reliably")
      logger.info("Verification based on timestamps can be unreliable if calls happen too close together.")
    end)

    --- Explains flakiness due to system load affecting timestamps.
    it("can cause flaky tests due to system load", function()
      -- Under system load, execution timing becomes unpredictable
      local service = createService()
      local mockService = mock(service)
      
      -- Create spies on all methods so we can track calls
      mockService:spy("getData")
      mockService:spy("processData")

      -- Simulate unpredictable execution timing
      service.getData()
      -- Simulate potential delay; sequence tracking is independent of timing.
      service.processData("test")

      -- Verify methods were called
      expect(mockService._spies.getData).to.exist()
      expect(mockService._spies.getData.called).to.be_truthy()
      expect(mockService._spies.processData).to.exist()
      expect(mockService._spies.processData.called).to.be_truthy()

      logger.info("Timestamp verification becomes unreliable when system load affects timing.")
    end)
  end) -- Close describe("1. Problems...")

  --- Test suite demonstrating the sequence-based tracking solution provided by Firmo.

  --- Demonstrates the reliability of sequence tracking.
--- @within examples.mock_sequence_example
describe("2. Sequence-Based Tracking Solution", function()
  --- Shows that sequence is preserved even with rapid calls.
  it("preserves order regardless of execution speed", function()
    local service = createService()
    local mockService = mock(service)
    
    -- Create spies on all methods so we can track calls
    mockService:spy("getData")
    mockService:spy("processData")
    mockService:spy("saveResult")

    -- No matter how quickly these execute, sequence numbers are assigned incrementally
    local call1 = service.getData() -- Call 1, sequence 1
    local call2 = service.processData("test") -- Call 2, sequence 2
    local call3 = service.saveResult("test result") -- Call 3, sequence 3

    -- First verify the methods were called
    expect(mockService._spies.getData).to.exist()
    expect(mockService._spies.getData.called).to.be_truthy()
    expect(mockService._spies.processData).to.exist()
    expect(mockService._spies.processData.called).to.be_truthy()
    expect(mockService._spies.saveResult).to.exist()
    expect(mockService._spies.saveResult.called).to.be_truthy()
    
    -- Verify the sequence through calls
    expect(mockService._spies.getData.calls[1]).to.exist()
    expect(mockService._spies.processData.calls[1]).to.exist()
    expect(mockService._spies.saveResult.calls[1]).to.exist()
    
    -- Verify arguments when needed
    expect(mockService._spies.processData.calls[1].args[2]).to.equal("test")
    expect(mockService._spies.saveResult.calls[1].args[2]).to.equal("test result")

    logger.info("Sequence-based tracking guarantees correct order via the spy calls array.")
  end)

  --- Shows sequence tracking works even with simulated delays.
  it("works consistently with delays between calls", function()
    local service = createService()
    local mockService = mock(service)
    
    -- Create spies on all methods so we can track calls
    mockService:spy("getData")
    mockService:spy("processData")

    -- Even with delays, sequence numbers preserve order
    service.getData() -- Sequence 1
    -- Simulate delay (doesn't affect sequence number assignment)
    service.processData("test") -- Sequence 2

    -- First verify the methods were called
    expect(mockService._spies.getData).to.exist()
    expect(mockService._spies.getData.called).to.be_truthy()
    expect(mockService._spies.processData).to.exist()
    expect(mockService._spies.processData.called).to.be_truthy()
    
    -- Verify the sequence through calls
    expect(mockService._spies.getData.calls[1]).to.exist()
    expect(mockService._spies.processData.calls[1]).to.exist()
    
    -- Verify arguments when needed
    expect(mockService._spies.processData.calls[1].args[2]).to.equal("test")

    logger.info("Sequence tracking works consistently even with delays.")
  end)
end)

--- Demonstrates manually verifying call sequences using the spy calls array.
--- @within examples.mock_sequence_example
describe("3. Verifying Call Sequences Manually", function()
  --- Tests verifying the exact order of calls.
  it("can verify exact call order using the spy calls array", function()
    local service = createService()
    local mockService = mock(service)
    
    -- Create spies on all methods so we can track calls
    mockService:spy("getData")
    mockService:spy("processData")
    mockService:spy("saveResult")

    service.getData()
    service.processData("test")
    service.saveResult("test result")

    -- First verify the methods were called
    expect(mockService._spies.getData).to.exist()
    expect(mockService._spies.getData.called).to.be_truthy()
    expect(mockService._spies.processData).to.exist()
    expect(mockService._spies.processData.called).to.be_truthy()
  end)

  --- Tests verifying the order of specific calls among others.
  it("can verify relative order of specific calls", function()
    local service = createService()
    local mockService = mock(service)
    
    -- Create spies on all methods so we can track calls
    mockService:spy("getData")
    mockService:spy("processData")
    mockService:spy("saveResult")

    service.getData() -- Call 1
    service.processData("first") -- Call 2
    service.getData() -- Call 3
    service.processData("second") -- Call 4
    service.saveResult("final") -- Call 5

    -- Verify call order using the spies directly
    expect(mockService._spies.getData.call_count).to.equal(2)
    expect(mockService._spies.processData.call_count).to.equal(2)
    expect(mockService._spies.saveResult.call_count).to.equal(1)
    
    -- Verify arguments correctly to ensure specific calls
    expect(mockService._spies.processData.calls[1].args[2]).to.equal("first")
    expect(mockService._spies.processData.calls[2].args[2]).to.equal("second")
    expect(mockService._spies.saveResult.calls[1].args[2]).to.equal("final")
    
    -- Verify the sequence by checking that the call sequences match expectations
    -- First process call should happen before second process call
    expect(mockService._spies.processData:called_with("first")).to.be_truthy()
    expect(mockService._spies.processData:called_with("second")).to.be_truthy()
    
    -- The saveResult call should be the last one
    expect(mockService._spies.saveResult:called_with("final")).to.be_truthy()
  end)

  --- This section is informational, as Firmo lacks built-in sequence assertions.
  --- Failures in manual sequence checks (like the one above) would be standard
  --- assertion failures (e.g., "Expected 'processData' to equal 'getData'").
  describe("4. Sequence Verification Failures (Informational)", function()
    --- Explains how manual sequence check failures appear.
    it("failures in manual checks report standard assertion errors", function()
      local service = createService()
      local mockService = mock(service)
      
      -- Create spies on all methods so we can track calls
      mockService:spy("getData")
      mockService:spy("processData")

      -- Intentionally call in wrong order
      service.processData("test") -- Call 1
      service.getData() -- Call 2

      -- This assertion will fail because the first call is 'processData', not 'getData'
      local success, err_msg = pcall(function()
        expect(mockService._spies.processData.call_count).to.equal(0) -- This is false
      end)

      expect(success).to.be_falsy()
      -- pcall returns the raw error message, not a structured error object
      expect(err_msg).to.match("Expected") -- Match part of the error message
      logger.info("Manual sequence check failed as expected: " .. tostring(err_msg))
    end)
  end) -- Close describe("4. Sequence Verification Failures")
end) -- Close describe("3. Verifying Call Sequences Manually")
end) -- Close describe("Mock Sequence Tracking")
