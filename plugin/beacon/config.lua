---@module "beacon.config"
---@author sravioli
---@license GNU-GPLv2

local wezterm = require "wezterm"

---@alias Beacon.Channel "stable"|"unstable"

---@class Beacon.Options
---@field repository string GitHub repository to watch, as `owner/name`.
---@field dir? string Local checkout to compare against. Defaults to `wezterm.config_dir`.
---@field channel? Beacon.Channel `stable` watches releases, `unstable` watches a branch.
---@field branch? string Branch watched by `unstable`. Defaults to the checked-out branch.
---@field interval_hours? number Hours between checks. Minimum 1, default 24.
---@field delay_seconds? number Seconds to wait after the first window event. Default 5.
---@field name? string Label used in notification titles. Defaults to `repository`.
---@field timeout_ms? integer Notification display time. Default 8000.

---@class Beacon.Config: Beacon.Options
---@field dir string
---@field channel Beacon.Channel
---@field interval_seconds integer
---@field delay_seconds number
---@field name string
---@field timeout_ms integer

local M = {}

local channels = { stable = true, unstable = true }

local function positive_number(value, field, default)
  if value == nil then
    return default
  end
  if type(value) ~= "number" or value < 0 then
    error(("`%s` must be a non-negative number."):format(field), 0)
  end
  return value
end

local function optional_string(value, field)
  if value ~= nil and (type(value) ~= "string" or value == "") then
    error(("`%s` must be a non-empty string."):format(field), 0)
  end
  return value
end

---Validate options and fill in defaults. Pure: performs no I/O.
---@param opts Beacon.Options
---@return Beacon.Config
function M.resolve(opts)
  if type(opts) ~= "table" then
    error("Options must be a table.", 0)
  end
  local repository = opts.repository
  if type(repository) ~= "string" or not repository:match "^[%w%-%._]+/[%w%-%._]+$" then
    error(('Invalid repository %q; use "owner/name".'):format(tostring(repository)), 0)
  end
  local channel = opts.channel or "stable"
  if not channels[channel] then
    error(('Unknown channel %q; use "stable" or "unstable".'):format(tostring(channel)), 0)
  end
  local hours = positive_number(opts.interval_hours, "interval_hours", 24)
  return {
    repository = repository,
    dir = optional_string(opts.dir, "dir") or wezterm.config_dir,
    channel = channel,
    branch = optional_string(opts.branch, "branch"),
    interval_seconds = math.floor(math.max(hours, 1) * 3600),
    delay_seconds = positive_number(opts.delay_seconds, "delay_seconds", 5),
    name = optional_string(opts.name, "name") or repository,
    timeout_ms = math.floor(positive_number(opts.timeout_ms, "timeout_ms", 8000)),
  }
end

return M
