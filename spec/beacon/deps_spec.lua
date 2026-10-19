local wezterm = require "wezterm"

describe("beacon dependencies", function()
  local deps

  before_each(function()
    wezterm._reset()
    deps = require "beacon.deps"
  end)

  after_each(function()
    package.loaded["warp.api"] = nil
    package.loaded["log.api"] = nil
  end)

  it("prefers local api modules before plugin URLs", function()
    local local_warp = { local_api = true }
    package.loaded["warp.api"] = local_warp
    assert.equal(local_warp, deps.warp())
    assert.equal(local_warp, deps.warp())
  end)

  it("falls back to wezterm.plugin.require and caches the result", function()
    local calls = 0
    wezterm.plugin.require = function()
      calls = calls + 1
      return wezterm._warp
    end
    assert.equal(wezterm._warp, deps.warp())
    deps.warp()
    assert.equals(1, calls)
  end)

  it("raises a useful error when warp cannot be loaded", function()
    wezterm._warp = nil
    local ok, err = pcall(deps.warp)
    assert.is_false(ok)
    assert.truthy(tostring(err):find("unable to load dependency", 1, true))
  end)

  it("returns nil for an unavailable optional dependency", function()
    local plugin, err = deps.optional "log"
    assert.is_nil(plugin)
    assert.truthy(tostring(err):find("disabled in specs", 1, true))
  end)

  it("reports unknown dependencies", function()
    local plugin, err = deps.optional "missing"
    assert.is_nil(plugin)
    assert.equal("unknown dependency: missing", err)
  end)
end)
