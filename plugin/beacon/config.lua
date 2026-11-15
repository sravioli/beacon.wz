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
---@field notify? boolean Set to `false` to skip toasts and only record updates for `available()`. Default true.
---@field validate? boolean Set to `false` to skip validation and never load warden. Default true.

---@class Beacon.Config: Beacon.Options
---@field dir string
---@field channel Beacon.Channel
---@field interval_seconds integer
---@field delay_seconds number
---@field name string
---@field timeout_ms integer
---@field notify boolean

local M = {}

---@return Warden.Schema
local function text()
  return require("beacon.deps").warden().string():not_empty():optional()
end

---@return Warden.Schema
local function schema()
  local w = require("beacon.deps").warden()
  return w.object({
    repository = w.string():matches "^[%w%-%._]+/[%w%-%._]+$",
    dir = text(),
    channel = w.enum({ "stable", "unstable" }):optional(),
    branch = text(),
    interval_hours = w.number():min(0):optional(),
    delay_seconds = w.number():min(0):optional(),
    name = text(),
    timeout_ms = w.number():min(0):optional(),
    notify = w.boolean():optional(),
    validate = w.boolean():optional(),
  }):unknown "warn"
end

---Validate options and fill in defaults. Raises on the first invalid option
---and warns about unknown ones. Performs no I/O beyond logging.
---@param opts Beacon.Options
---@return Beacon.Config
function M.resolve(opts)
  if type(opts) ~= "table" then
    error("Options must be a table.", 0)
  end
  if opts.validate ~= false then
    local result = schema():safe_parse(opts)
    if not result.ok then
      local issue = result.issues[1]
      error(("Invalid option `%s`: %s"):format(issue.path_text, issue.message), 0)
    end
    result:log { warn = require("beacon.logger").warn }
  end

  return {
    repository = opts.repository,
    dir = opts.dir or wezterm.config_dir,
    channel = opts.channel or "stable",
    branch = opts.branch,
    interval_seconds = math.floor(math.max(opts.interval_hours or 24, 1) * 3600),
    delay_seconds = opts.delay_seconds or 5,
    name = opts.name or opts.repository,
    timeout_ms = math.floor(opts.timeout_ms or 8000),
    notify = opts.notify ~= false,
  }
end

return M
