-- Checked first: loading beacon must not read its mosaic integration.
local read_by_beacon = package.loaded["beacon.mosaic.update"] ~= nil

describe("mosaic integration beacon.update", function()
  local beacon, descriptor, updates
  local mosaic = {
    palette = {
      accent = function(i)
        return function()
          return { fg = "accent" .. i }
        end
      end,
    },
  }

  before_each(function()
    beacon = require "beacon.api"
    descriptor = require "beacon.mosaic.update"
    updates = {}
    beacon.available = function()
      return updates
    end
  end)

  after_each(function()
    package.loaded["beacon.api"] = nil
  end)

  it("is not read when beacon loads", function()
    assert.is_false(read_by_beacon)
  end)

  it("follows the descriptor contract", function()
    assert.equals(1, descriptor.api)
    assert.is_function(descriptor.new)
    assert.is_function(descriptor.new({}, mosaic))
  end)

  it("hides while no update is known", function()
    assert.is_false(descriptor.new({}, mosaic)().enabled)
  end)

  it("shows how many repositories have updates", function()
    updates = { { key = "release:6.4.0", version = "6.4.0" } }
    local spec = descriptor.new({}, mosaic)()
    assert.is_true(spec.enabled)
    assert.is_true(spec.can_hide)
    assert.equals("1", spec.text.value)
    assert.equals(4, spec.accent)
    assert.is_nil(spec.style) -- content only: the preset decorates it
    updates = { { version = "1.2.0" }, { version = "0.2.0" }, { key = "commit:abc" } }
    assert.equals("3", descriptor.new({}, mosaic)().text.value)
  end)

  it("hides the icon with icon = false", function()
    updates = { { key = "release:1.0.0", version = "1.0.0" } }
    assert.is_false(descriptor.new({ icon = false }, mosaic)().icon.enabled)
    assert.equals("U", descriptor.new({ icon = "U" }, mosaic)().icon.value)
  end)
end)
