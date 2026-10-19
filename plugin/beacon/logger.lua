---@module "beacon.logger"
---@author sravioli
---@license GNU-GPLv2

---Logs through log.wz when it is available, otherwise through `wezterm.log_*`.
---log.wz's global configuration is left alone.

local deps = require "beacon.deps"
local wezterm = require "wezterm"

local TAG = "beacon"

---@class Beacon.Logger
local M = {}

local external ---@type table|false|nil

---Resolve log.wz once; `setup` calls this so checks never load plugins.
---@return table|false
function M.resolve()
  if external == nil then
    local log = deps.optional "log"
    local ok, logger = false, nil
    if log and type(log.new) == "function" then
      ok, logger = pcall(log.new, TAG)
    end
    external = ok and type(logger) == "table" and logger or false
  end
  return external
end

---@param level "info"|"warn"|"error"
---@param message any
local function write(level, message)
  message = tostring(message)
  local logger = M.resolve()
  if logger and type(logger[level]) == "function" then
    -- Pass the message as an argument so `%` in it is never treated as format.
    if pcall(logger[level], logger, "%s", message) then
      return
    end
  end
  wezterm["log_" .. level](("[%s] %s"):format(TAG, message))
end

---@param message any
function M.info(message)
  write("info", message)
end

---@param message any
function M.warn(message)
  write("warn", message)
end

---@param message any
function M.error(message)
  write("error", message)
end

---Forget the resolved logger (specs).
function M._reset()
  external = nil
end

return M
