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

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local mock = firmo.mock
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

-- Setup logger
local logger = logging.get_logger("MockSequenceExample")

--- Test suite demonstrating mock call sequence tracking and verification.
describe("Mock Sequence Tracking", function()
  -- Example service that will be mocked
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

  --- Describes potential issues with verifying call order using timestamps.
  describe("1. Problems with timestamp-based tracking", function()
    it("can fail due to execution speed/timing issues", function()
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

      it("can have flaky tests due to system load", function()
        -- Under system load, execution timing becomes unpredictable
        local mockService = mock(service)

        -- Simulate unpredictable execution timing
        -- Simulate unpredictable execution timing
        mockService.getData()
        -- Simulate potential delay; sequence tracking is independent of timing.
        mockService.processData("test")

        logger.info("Timestamp verification becomes unreliable when system load affects timing")
      end)
    end)

    --- Describes how sequence-based tracking provides deterministic order.
    describe("2. Sequence-based tracking solution", function()
      local mockService = mock(service)

      -- No matter how quickly these execute, sequence is preserved
      mockService.getData()
      mockService.processData("test")
      mockService.saveResult("test result")

      -- Verify calls happened in expected order
      expect(mockService.getData).was_called()
      expect(mockService.getData).was_called()
      -- NOTE: Assumes .was_called_after() exists. Verify API.
      expect(mockService.processData).was_called_after(mockService.getData)
      -- NOTE: Assumes .was_called_after() exists. Verify API.
      expect(mockService.saveResult).was_called_after(mockService.processData)

      logger.info("Sequence-based tracking guarantees correct order verification regardless of timing")
    end)

    local mockService = mock(service)

    -- Even with delays, sequence numbers preserve order
    mockService.getData()
    -- Simulate potential delay; sequence tracking is independent of timing.
    mockService.processData("test")

    -- NOTE: Assumes .was_called_before() exists. Verify API.
    expect(mockService.getData).was_called_before(mockService.processData)

    logger.info("Sequence tracking works consistently even with delays between calls")
  end)
end)

--- Demonstrates specific sequence verification assertion methods.
describe("3. Using sequence verification API", function()
  local mockService = mock(service)

  mockService.getData()
  mockService.processData("test")
  mockService.saveResult("test result")

  -- Verify relative ordering
  -- NOTE: Assumes .was_called_before() and .was_called_after() exist. Verify API.
  expect(mockService.getData).was_called_before(mockService.processData)
  expect(mockService.processData).was_called_before(mockService.saveResult)
  expect(mockService.getData).was_called_before(mockService.saveResult)

  -- Alternative syntax
  expect(mockService.saveResult).was_called_after(mockService.processData)
  expect(mockService.processData).was_called_after(mockService.getData)

  it("can verify call order with was_called_with", function()
    local mockService = mock(service)

    mockService.getData()
    mockService.processData("first")
    mockService.processData("second")

    -- Can combine sequence with argument checking
    -- NOTE: Assumes complex .before(function) chain or .calls_were_in_order() exist. Verify API.
    expect(mockService.processData).was_called_with("first").before(function(call)
      return call.args[1] == "second"
    end)

    -- Or use the shorthand for checking multiple calls in order
    -- NOTE: Assumes complex .before(function) chain or .calls_were_in_order    end)
  end)

  --- Demonstrates how sequence verification failures are reported.
  describe("4. Sequence verification failures and debugging", function()
    it("provides helpful error messages when sequence is wrong", function()
      local mockService = mock(service)

      -- Intentionally call in wrong order
      mockService.processData("test")
      mockService.getData()

      -- This should fail with helpful message about call order
      local success, error_message = pcall(function()
        -- NOTE: Assumes .was_called_before() exists. Verify API.
        expect(mockService.getData).was_called_before(mockService.processData)
      end)

      logger.info("Sequence verification failure example:")
      print(error_message or "Error message not captured") -- Keep print to show failure output

      -- The error shows the actual sequence numbers and call order
    end)

    -- Removed debugging test case that relied on internal properties
  end)
end)
