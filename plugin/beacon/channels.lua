---@module "beacon.channels"
---@author sravioli
---@license GNU-GPLv2

local deps = require "beacon.deps"
local logger = require "beacon.logger"
local wezterm = require "wezterm"

---@class Beacon.Notice
---@field key string Deduplication key; the same key is never notified twice in a row.
---@field title string
---@field message string
---@field url string

local M = {}

-- ── Helpers ─────────────────────────────────────────────────────────────────

-- warp.process resolves git/curl outside PATH too (GUI-launched WezTerm).
---@param args string[]
---@return boolean ok
---@return string stdout
---@return string stderr
local function exec(args)
  return deps.warp().process.run(args)
end

local function run(args)
  local success, stdout, stderr = exec(args)
  if not success then
    error(("%s failed: %s"):format(args[1], stderr), 0)
  end
  return stdout:match "^%s*(.-)%s*$"
end

local function git(cfg, ...)
  return run { "git", "-C", cfg.dir, ... }
end

---@param tag any
---@return integer[]|nil
function M.parse_version(tag)
  local major, minor, patch = tostring(tag):match "^v?(%d+)%.(%d+)%.(%d+)"
  if major then
    return { tonumber(major), tonumber(minor), tonumber(patch) }
  end
end

---@param candidate integer[]
---@param installed integer[]
---@return boolean
function M.is_newer(candidate, installed)
  for i = 1, 3 do
    if candidate[i] ~= installed[i] then
      return candidate[i] > installed[i]
    end
  end
  return false
end

-- ── Channels ────────────────────────────────────────────────────────────────

---Report when the latest published release is newer than the nearest local tag.
---@param cfg Beacon.Config
---@return Beacon.Notice|nil
function M.stable(cfg)
  local repository = cfg.repository
  local installed_tag = git(cfg, "describe", "--tags", "--abbrev=0", "HEAD")
  local installed = M.parse_version(installed_tag)
  if not installed then
    error(("Installed tag %q is not a version."):format(installed_tag), 0)
  end
  local result = wezterm.json_parse(run {
    "curl",
    "--disable",
    "--silent",
    "--show-error",
    "--fail",
    "--connect-timeout",
    "5",
    "--max-time",
    "15",
    "--header",
    "Accept: application/vnd.github+json",
    "--user-agent",
    "beacon.wz",
    "https://api.github.com/repos/" .. repository .. "/releases/latest",
  })
  local tag = type(result) == "table" and result.tag_name
  local url = type(result) == "table" and result.html_url
  local latest = M.parse_version(tag)
  local prefix = "https://github.com/" .. repository .. "/releases/"
  if not latest or type(url) ~= "string" or url:sub(1, #prefix) ~= prefix then
    error("Unexpected GitHub release response.", 0)
  end
  if not M.is_newer(latest, installed) then
    return nil
  end
  return {
    key = "release:" .. tag,
    title = cfg.name .. " release",
    message = ("Version %s is available (installed: %s)."):format(tag, installed_tag),
    url = url,
  }
end

---Report when the remote branch tip is not contained in the local HEAD.
---@param cfg Beacon.Config
---@return Beacon.Notice|nil
function M.unstable(cfg)
  local branch = cfg.branch or git(cfg, "branch", "--show-current")
  if branch == "" then
    logger.info "Skipping detached HEAD; set `branch` to check one."
    return nil
  end
  local remote = run {
    "git",
    "-c",
    "http.lowSpeedLimit=1",
    "-c",
    "http.lowSpeedTime=15",
    "ls-remote",
    "--exit-code",
    "https://github.com/" .. cfg.repository .. ".git",
    "refs/heads/" .. branch,
  }
  local tip = remote:match "^(%x+)%s"
  if not tip then
    error(("Unexpected ls-remote output for %s."):format(branch), 0)
  end
  -- Fails both when the tip is missing locally and when it is not merged.
  local up_to_date = exec {
    "git",
    "-C",
    cfg.dir,
    "merge-base",
    "--is-ancestor",
    tip,
    "HEAD",
  }
  if up_to_date then
    return nil
  end
  return {
    key = "commit:" .. tip,
    title = cfg.name .. " update",
    message = ("New commits are available on %s. Update manually when ready."):format(branch),
    url = "https://github.com/" .. cfg.repository .. "/commits/" .. branch,
  }
end

return M
