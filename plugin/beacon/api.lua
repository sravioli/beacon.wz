---@module "beacon.api"
---@author sravioli
---@license GNU-GPLv2

local channels = require "beacon.channels"
local config = require "beacon.config"
local deps = require "beacon.deps"
local logger = require "beacon.logger"
local wezterm = require "wezterm"

---@class Beacon
local M = {}

local cfg ---@type Beacon.Config|nil
local registered = false
local scheduled = false

-- ── State ───────────────────────────────────────────────────────────────────

-- wezterm.GLOBAL survives config reloads, so cooldown and dedup do too.
local function state_key()
  return ("__beacon:%s:%s"):format(cfg.repository, cfg.channel)
end

local function load_state()
  return wezterm.GLOBAL[state_key()] or {}
end

local function save_state(state)
  wezterm.GLOBAL[state_key()] = state
end

-- ── Checks ──────────────────────────────────────────────────────────────────

---@param window table
---@param force boolean
---@return Beacon.Notice|nil
local function run_check(window, force)
  local notice = channels[cfg.channel](cfg)
  if not notice then
    return nil
  end
  local state = load_state()
  if force or state.notified ~= notice.key then
    window:toast_notification(notice.title, notice.message, notice.url, cfg.timeout_ms)
    state.notified = notice.key
    save_state(state)
  end
  return notice
end

local function on_status(window)
  if not cfg or scheduled or os.time() < (load_state().next_check or 0) then
    return
  end
  scheduled = true
  -- Only a live window event can schedule work; setup never does I/O.
  wezterm.time.call_after(cfg.delay_seconds, function()
    scheduled = false
    local state = load_state()
    if os.time() < (state.next_check or 0) then
      return
    end
    -- Set before checking so failures are throttled too.
    state.next_check = os.time() + cfg.interval_seconds
    save_state(state)
    local ok, err = pcall(run_check, window, false)
    if not ok then
      logger.warn(err)
    end
  end)
end

-- ── Public API ──────────────────────────────────────────────────────────────

---Configure beacon and start watching after the first window event.
---Invalid options or a missing warp.wz are logged and leave beacon disabled.
---@param opts Beacon.Options
---@return boolean ok
function M.setup(opts)
  local ok, resolved = pcall(config.resolve, opts)
  if not ok then
    logger.error(resolved)
    return false
  end
  -- Load dependencies now, while the config is evaluated, so checks never do.
  local loaded, err = pcall(deps.warp)
  if not loaded then
    logger.error(err)
    return false
  end
  logger.resolve()
  cfg = resolved
  if not registered then
    registered = true
    wezterm.on("update-status", on_status)
  end
  return true
end

---Check immediately, ignoring the cooldown and repeating already shown notices.
---Call it from an async context such as `wezterm.action_callback`.
---@param window table
---@return Beacon.Notice|nil notice
function M.check_now(window)
  if not cfg then
    logger.warn "check_now called before setup."
    return nil
  end
  local ok, notice = pcall(run_check, window, true)
  if not ok then
    logger.warn(notice)
    return nil
  end
  if not notice then
    window:toast_notification(cfg.name, "Already up to date.", nil, cfg.timeout_ms)
  end
  return notice
end

---Return the resolved configuration, or nil before setup.
---@return Beacon.Config|nil
function M.config()
  return cfg
end

return M
