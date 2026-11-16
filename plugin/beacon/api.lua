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

---@class Beacon.Watch
---@field cfg Beacon.Config
---@field scheduled boolean
---@field verified? boolean The recorded update was checked against the checkout this load.

local watches = {} ---@type Beacon.Watch[]
local registered = false

-- ── State ───────────────────────────────────────────────────────────────────

-- wezterm.GLOBAL survives config reloads, so cooldown and dedup do too.
---@param cfg Beacon.Config
local function state_key(cfg)
  return ("__beacon:%s:%s"):format(cfg.repository, cfg.channel)
end

---@param cfg Beacon.Config
local function load_state(cfg)
  return wezterm.GLOBAL[state_key(cfg)] or {}
end

---@param cfg Beacon.Config
local function save_state(cfg, state)
  wezterm.GLOBAL[state_key(cfg)] = state
end

-- ── Checks ──────────────────────────────────────────────────────────────────

---@param cfg Beacon.Config
---@param window table
---@param force boolean
---@return Beacon.Notice|nil
local function run_check(cfg, window, force)
  local notice = channels[cfg.channel](cfg)
  local state = load_state(cfg)
  -- What `available()` reports: the latest check's notice, or nothing once
  -- up to date.
  state.available = notice
      and {
        key = notice.key,
        title = notice.title,
        message = notice.message,
        url = notice.url,
        version = notice.version,
        name = cfg.name,
        installed = channels.installed(cfg),
      }
    or nil
  -- `notify = false` watches only feed `available()`; check_now still toasts.
  if notice and (force or (cfg.notify and state.notified ~= notice.key)) then
    window:toast_notification(notice.title, notice.message, notice.url, cfg.timeout_ms)
    state.notified = notice.key
  end
  save_state(cfg, state)
  return notice
end

---Drop a recorded update once the checkout no longer has the version it was
---found against (e.g. after `wezterm.plugin.update_all()`), and check again.
---Local git only; runs once per config load.
---@param watch Beacon.Watch
local function verify(watch)
  watch.verified = true
  local cfg = watch.cfg
  local state = load_state(cfg)
  if not state.available then
    return
  end
  local ok, installed = pcall(channels.installed, cfg)
  if ok and installed ~= state.available.installed then
    state.available, state.next_check = nil, 0
    save_state(cfg, state)
  end
end

---@param watch Beacon.Watch
---@param window table
local function schedule(watch, window)
  local cfg = watch.cfg
  local state = load_state(cfg)
  local stale = not watch.verified and state.available ~= nil
  if watch.scheduled or (not stale and os.time() < (state.next_check or 0)) then
    return
  end
  watch.scheduled = true
  -- Only a live window event can schedule work; setup never does I/O.
  wezterm.time.call_after(cfg.delay_seconds, function()
    watch.scheduled = false
    if not watch.verified then
      verify(watch)
    end
    state = load_state(cfg)
    if os.time() < (state.next_check or 0) then
      return
    end
    -- Set before checking so failures are throttled too.
    state.next_check = os.time() + cfg.interval_seconds
    save_state(cfg, state)
    local ok, err = pcall(run_check, cfg, window, false)
    if not ok then
      logger.warn(err)
    end
  end)
end

local function on_status(window)
  for _, watch in ipairs(watches) do
    schedule(watch, window)
  end
end

---Resolve `opts` and add (or replace) the watch for its repository/channel.
---@param opts Beacon.Options
---@return boolean ok
local function add(opts)
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
  local key = state_key(resolved)
  local slot = #watches + 1
  for i, watch in ipairs(watches) do
    if state_key(watch.cfg) == key then
      slot = i
    end
  end
  watches[slot] = { cfg = resolved, scheduled = watches[slot] and watches[slot].scheduled or false }
  if not registered then
    registered = true
    wezterm.on("update-status", on_status)
  end
  return true
end

-- ── Public API ──────────────────────────────────────────────────────────────

---Configure beacon and start watching after the first window event.
---Replaces every watch with this one. Add more with `beacon.watch`.
---Invalid options or a missing warp.wz are logged and leave beacon disabled.
---@param opts Beacon.Options
---@return boolean ok
function M.setup(opts)
  watches = {}
  return add(opts)
end

---Watch one more repository (same options as `setup`), e.g. each plugin
---your config loads. Each watch keeps its own cooldown, dedup and notice.
---@param opts Beacon.Options
---@return boolean ok
function M.watch(opts)
  return add(opts)
end

---Check every watch immediately, ignoring the cooldown and repeating already
---shown notices. Call it from an async context such as
---`wezterm.action_callback`.
---@param window table
---@return Beacon.Notice|nil notice The first update found.
function M.check_now(window)
  if #watches == 0 then
    logger.warn "check_now called before setup."
    return nil
  end
  local first
  for _, watch in ipairs(watches) do
    local ok, notice = pcall(run_check, watch.cfg, window, true)
    if not ok then
      logger.warn(notice)
    elseif notice and not first then
      first = notice
    end
  end
  if not first then
    local cfg = watches[1].cfg
    window:toast_notification(cfg.name, "Already up to date.", nil, cfg.timeout_ms)
  end
  return first
end

---Updates found by the latest checks, one per watch with an update, in watch
---order. Empty when everything is up to date, not yet checked, or before
---setup. Reads `wezterm.GLOBAL` only, so it is cheap enough for
---`update-status`.
---@return Beacon.Notice[]
function M.available()
  local out = {}
  for _, watch in ipairs(watches) do
    local notice = load_state(watch.cfg).available
    if notice then
      out[#out + 1] = notice
    end
  end
  return out
end

---Return the configuration of the first watch, or nil before setup.
---@return Beacon.Config|nil
function M.config()
  return watches[1] and watches[1].cfg
end

return M
