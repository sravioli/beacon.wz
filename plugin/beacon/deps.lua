---@module "beacon.deps"
---@author sravioli
---@license GNU-GPLv2

---Dependency loader. Prefers modules already on `package.path` (local dev
---checkouts, specs) and falls back to `wezterm.plugin.require`. `setup`
---resolves dependencies so checks never load plugins.

local wezterm = require "wezterm"

---@class Beacon.Dependency
---@field module string
---@field url string

---@class Beacon.Deps
local M = {
  _cache = {},
}

---@type table<string, Beacon.Dependency>
M.plugins = {
  log = {
    module = "log.api",
    url = "https://github.com/sravioli/log.wz",
  },
  warp = {
    module = "warp.api",
    url = "https://github.com/sravioli/warp.wz",
  },
}

---Load a dependency, returning nil and the error when it is unavailable.
---@param name string
---@return table|nil plugin
---@return any error
function M.optional(name)
  local spec = M.plugins[name]
  if not spec then
    return nil, ("unknown dependency: %s"):format(tostring(name))
  end

  if M._cache[name] then
    return M._cache[name], nil
  end

  local ok, plugin = pcall(require, spec.module)
  if ok and plugin then
    M._cache[name] = plugin
    return plugin, nil
  end

  ok, plugin = pcall(wezterm.plugin.require, spec.url)
  if ok and plugin then
    M._cache[name] = plugin
    return plugin, nil
  end

  return nil, plugin
end

---@param name string
---@return table
local function require_dependency(name)
  local plugin, err = M.optional(name)
  if plugin then
    return plugin
  end
  error(("unable to load dependency %s: %s"):format(M.plugins[name].url, tostring(err)), 0)
end

---@return Warp.Api
function M.warp()
  return require_dependency "warp"
end

return M
