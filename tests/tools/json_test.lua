--- JSON Module Tests
---
--- Verifies the encoding and decoding functionality of the `lib.tools.json` module.
--- Covers:
--- - Encoding/decoding of simple values (string, number, boolean, nil).
--- - Encoding/decoding of arrays and objects (tables).
--- - Handling of nested structures.
--- - Correct handling of special numbers (NaN, Infinity).
--- - Escaping/unescaping of special characters in strings.
--- - Graceful error handling for invalid inputs (non-string for decode, function for encode).
--- - Round-trip consistency (encode then decode).
---
--- @author Firmo Team
--- @test
local firmo = require("firmo")

local test_helper = require("lib.tools.test_helper")
local json = require("lib.tools.json")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("JSON Module", function()
  describe("Encoding", function()
    it("should encode simple values", function()
      expect(json.encode("test")).to.equal('"test"')
      expect(json.encode(42)).to.equal("42")
      expect(json.encode(true)).to.equal("true")
      expect(json.encode(false)).to.equal("false")
      expect(json.encode(nil)).to.equal("null")
    end)

    it("should encode arrays", function()
      expect(json.encode({})).to.equal("[]")
      expect(json.encode({ 1, 2, 3 })).to.equal("[1,2,3]")
      expect(json.encode({ "a", "b" })).to.equal('["a","b"]')
    end)

    it("should encode objects", function()
      expect(json.encode({ name = "test" })).to.equal('{"name":"test"}')
      expect(json.encode({ x = 1, y = 2 })).to.match('"x":1')
      expect(json.encode({ x = 1, y = 2 })).to.match('"y":2')
    end)

    it("should encode nested structures", function()
      local data = {
        items = {
          { id = 1, name = "first" },
          { id = 2, name = "second" },
        },
        count = 2,
      }
      local encoded = json.encode(data)
      expect(encoded).to.match('"items":%[')
      expect(encoded).to.match('"id":1')
      expect(encoded).to.match('"name":"first"')
      expect(encoded).to.match('"count":2')
    end)

    it("should handle special numbers", function()
      expect(json.encode(0 / 0)).to.equal("null") -- NaN
      expect(json.encode(math.huge)).to.equal("null") -- Infinity
      expect(json.encode(-math.huge)).to.equal("null") -- -Infinity
    end)

    it("should handle special characters in strings", function()
      expect(json.encode("hello\nworld")).to.equal('"hello\\nworld"')
      expect(json.encode('quote"here')).to.equal('"quote\\"here"')
      expect(json.encode("tab\there")).to.equal('"tab\\there"')
    end)

    it("should handle invalid values gracefully", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return json.encode(function() end)
      end)()

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("Cannot encode value of type function")
    end)
  end)

  describe("Decoding", function()
    it("should decode simple values", function()
      expect(json.decode('"test"')).to.equal("test")
      expect(json.decode("42")).to.equal(42)
      expect(json.decode("true")).to.equal(true)
      expect(json.decode("false")).to.equal(false)
      expect(json.decode("null")).to.equal(nil)
    end)

    it("should decode arrays", function()
      local arr1 = json.decode("[]")
      expect(#arr1).to.equal(0)

      local arr2 = json.decode("[1,2,3]")
      expect(#arr2).to.equal(3)
      expect(arr2[1]).to.equal(1)
      expect(arr2[2]).to.equal(2)
      expect(arr2[3]).to.equal(3)
    end)

    it("should decode objects", function()
      local obj1 = json.decode('{"name":"test"}')
      expect(obj1.name).to.equal("test")

      local obj2 = json.decode('{"x":1,"y":2}')
      expect(obj2.x).to.equal(1)
      expect(obj2.y).to.equal(2)
    end)

    it("should decode nested structures", function()
      local json_str = [[
        {
          "items": [
            {"id": 1, "name": "first"},
            {"id": 2, "name": "second"}
          ],
          "count": 2
        }
      ]]

      local data = json.decode(json_str)
      expect(data.count).to.equal(2)
      expect(#data.items).to.equal(2)
      expect(data.items[1].id).to.equal(1)
      expect(data.items[1].name).to.equal("first")
      expect(data.items[2].id).to.equal(2)
      expect(data.items[2].name).to.equal("second")
    end)

    it("should handle whitespace", function()
      local json_str = [[
        {
          "name": "test",
          "values": [
            1,
            2,
            3
          ]
        }
      ]]

      local data = json.decode(json_str)
      expect(data.name).to.equal("test")
      expect(#data.values).to.equal(3)
    end)

    it("should handle escaped characters", function()
      local data = json.decode('"hello\\nworld"')
      expect(data).to.equal("hello\nworld")

      data = json.decode('"tab\\there"')
      expect(data).to.equal("tab\there")

      data = json.decode('"quote\\"here"')
      expect(data).to.equal('quote"here')
    end)

    it("should handle invalid JSON gracefully", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return json.decode("invalid json")
      end)()

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("Invalid JSON")
    end)

    it("should handle invalid input type", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return json.decode(123)
      end)()

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("Expected string")
    end)
  end)

  describe("Round Trip", function()
    it("should preserve data through encode/decode", function()
      local original = {
        string = "test",
        number = 42,
        boolean = true,
        array = { 1, 2, 3 },
        object = {
          name = "nested",
          value = 123,
        },
      }

      local encoded = json.encode(original)
      local decoded = json.decode(encoded)

      expect(decoded.string).to.equal(original.string)
      expect(decoded.number).to.equal(original.number)
      expect(decoded.boolean).to.equal(original.boolean)
      expect(decoded.array[1]).to.equal(original.array[1])
      expect(decoded.array[2]).to.equal(original.array[2])
      expect(decoded.array[3]).to.equal(original.array[3])
      expect(decoded.object.name).to.equal(original.object.name)
      expect(decoded.object.value).to.equal(original.object.value)
    end)
  end)
end)
