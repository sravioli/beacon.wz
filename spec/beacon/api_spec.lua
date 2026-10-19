local wezterm = require "wezterm"

describe("beacon", function()
  local beacon, window, notices, options, release, branch, installed_tag, remote_tip
  local merged, fail_command, yield_command

  local function state_key()
    local cfg = beacon.config()
    return ("__beacon:%s:%s"):format(cfg.repository, cfg.channel)
  end

  local function state()
    return wezterm.GLOBAL[state_key()]
  end

  ---Simulate a config reload: fresh modules, same GLOBAL.
  local function reload()
    local global = wezterm.GLOBAL
    local timers = wezterm._timers
    wezterm._reset()
    wezterm.GLOBAL = global
    wezterm._timers = timers
    beacon = require "beacon.api"
    assert.is_true(beacon.setup(options))
  end

  local function status()
    wezterm._emit("update-status", window)
  end

  local function check()
    status()
    wezterm._fire()
  end

  local function find_command(predicate)
    for _, args in ipairs(wezterm._commands) do
      if predicate(args) then
        return args
      end
    end
  end

  local function is_curl(args)
    return args[1] == "curl"
  end

  local function respond(args)
    if args[1] == yield_command then
      coroutine.yield()
    end
    if args[1] == fail_command then
      return false, "", "test failure"
    end
    if args[1] == "curl" then
      wezterm._json["release response"] = release
      return true, "release response", ""
    end
    assert.equals("git", args[1])
    local sub = args[6] == "ls-remote" and "ls-remote" or args[4]
    if sub == "ls-remote" then
      return true, remote_tip .. "\trefs/heads/" .. args[#args]:sub(12) .. "\n", ""
    end
    assert.equals(beacon.config().dir, args[3])
    if sub == "describe" then
      return true, installed_tag .. "\n", ""
    elseif sub == "branch" then
      return true, branch .. "\n", ""
    elseif sub == "merge-base" then
      return merged, "", ""
    end
    error("unexpected git command " .. tostring(sub))
  end

  before_each(function()
    notices = {}
    options = { repository = "sravioli/wezterm", name = "WezTerm config" }
    branch, installed_tag = "feat/v7.0.0", "6.3.4"
    remote_tip, merged = string.rep("b", 40), false
    fail_command, yield_command = nil, nil
    release = {
      tag_name = "6.4.0",
      html_url = "https://github.com/sravioli/wezterm/releases/tag/6.4.0",
    }
    window = {
      toast_notification = function(_, ...)
        notices[#notices + 1] = { ... }
      end,
    }
    wezterm._reset()
    wezterm._timers = {}
    reload()
    wezterm._respond = respond
  end)

  -- ── Setup ─────────────────────────────────────────────────────────────────

  describe("setup", function()
    it("logs invalid options instead of raising and stays inactive", function()
      wezterm._reset()
      beacon = require "beacon.api"
      assert.is_false(beacon.setup { repository = "not a repo" })
      assert.matches("Invalid repository", wezterm._logs.error[1], 1, true)
      assert.is_nil(wezterm._handlers["update-status"])
    end)

    it("registers the handler once across repeated setup calls", function()
      assert.is_true(beacon.setup { repository = "someone/fork" })
      assert.equals(1, #wezterm._handlers["update-status"])
      assert.equals("someone/fork", beacon.config().repository)
    end)

    it("stays inactive when warp.wz cannot be loaded", function()
      wezterm._reset()
      wezterm._warp = nil
      beacon = require "beacon.api"
      assert.is_false(beacon.setup { repository = "sravioli/wezterm" })
      assert.matches("unable to load dependency", wezterm._logs.error[1], 1, true)
      assert.is_nil(wezterm._handlers["update-status"])
    end)

    it("logs through log.wz when it is available", function()
      local entries = {}
      package.loaded["log.api"] = {
        new = function(tag)
          return {
            warn = function(_, fmt, message)
              entries[#entries + 1] = { tag, fmt:format(message) }
            end,
          }
        end,
      }
      wezterm._reset()
      beacon = require "beacon.api"
      assert.is_true(beacon.setup(options))
      package.loaded["log.api"] = nil
      wezterm._respond = respond
      fail_command = "curl"
      check()
      assert.same({ "beacon", "curl failed: test failure" }, entries[1])
      assert.equals(0, #wezterm._logs.warn)
    end)
  end)

  -- ── Scheduling ────────────────────────────────────────────────────────────

  describe("scheduling", function()
    it("does no work until a live window event and the startup delay", function()
      assert.same({}, wezterm._commands)
      assert.same({}, wezterm._timers)
      status()
      assert.same({}, wezterm._commands)
      assert.equals(5, wezterm._timers[1].delay)
      wezterm._fire()
      assert.equals(1, #notices)
    end)

    it("honours delay_seconds", function()
      options.delay_seconds = 30
      reload()
      status()
      assert.equals(30, wezterm._timers[1].delay)
    end)

    it("shares the cooldown across windows and config reloads", function()
      status()
      status()
      assert.equals(1, #wezterm._timers)
      local before = os.time()
      wezterm._fire()
      assert.is_true(state().next_check >= before + 86400)
      reload()
      wezterm._respond = respond
      status()
      assert.same({}, wezterm._timers)
      assert.same({}, wezterm._commands)
    end)

    it("honours interval_hours", function()
      options.interval_hours = 2
      reload()
      wezterm._respond = respond
      local before = os.time()
      check()
      assert.is_true(state().next_check >= before + 7200)
      assert.is_true(state().next_check <= os.time() + 7200)
    end)

    it("reschedules after a reload cancels a pending timer", function()
      status()
      wezterm._timers = {}
      reload()
      wezterm._respond = respond
      status()
      assert.equals(1, #wezterm._timers)
      wezterm._fire()
      assert.equals(1, #notices)
    end)

    it("does not duplicate work from timers scheduled by different contexts", function()
      status()
      reload()
      wezterm._respond = respond
      status()
      assert.equals(2, #wezterm._timers)
      wezterm._fire()
      local count = #wezterm._commands
      wezterm._fire()
      assert.equals(count, #wezterm._commands)
      assert.equals(1, #notices)
    end)

    it("allows status events while the network request is suspended", function()
      yield_command = "curl"
      status()
      local worker = coroutine.create(table.remove(wezterm._timers, 1).callback)
      assert.is_true(coroutine.resume(worker))
      assert.equals("suspended", coroutine.status(worker))
      status()
      assert.same({}, wezterm._timers)
      assert.is_true(coroutine.resume(worker))
      assert.equals("dead", coroutine.status(worker))
      assert.equals(1, #notices)
    end)

    it("keeps separate cooldowns per repository and channel", function()
      check()
      options.channel = "unstable"
      reload()
      wezterm._respond = respond
      status()
      assert.equals(1, #wezterm._timers)
    end)
  end)

  -- ── Stable channel ────────────────────────────────────────────────────────

  describe("stable channel", function()
    it("is the default and notifies with the release page", function()
      check()
      assert.same({
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
        "https://api.github.com/repos/sravioli/wezterm/releases/latest",
      }, find_command(is_curl))
      assert.same({
        "WezTerm config release",
        "Version 6.4.0 is available (installed: 6.3.4).",
        release.html_url,
        8000,
      }, notices[1])
    end)

    for _, case in ipairs {
      { "6.3.4", "6.3.4", false },
      { "6.3.4", "6.3.3", false },
      { "6.3.4", "5.9.9", false },
      { "6.3.4", "6.3.10", true },
      { "6.3.4", "7.0.0", true },
      { "v6.3.4", "v6.4.0", true },
    } do
      it(("installed %s, latest %s"):format(case[1], case[2]), function()
        installed_tag = case[1]
        release.tag_name = case[2]
        release.html_url = "https://github.com/sravioli/wezterm/releases/tag/" .. case[2]
        check()
        assert.equals(case[3] and 1 or 0, #notices)
        assert.same({}, wezterm._logs.warn)
      end)
    end

    it("does not repeat a notification for the same release", function()
      check()
      wezterm.GLOBAL[state_key()] = { notified = state().notified }
      check()
      assert.equals(1, #notices)
      release.tag_name = "6.5.0"
      release.html_url = "https://github.com/sravioli/wezterm/releases/tag/6.5.0"
      wezterm.GLOBAL[state_key()] = { notified = state().notified }
      check()
      assert.equals(2, #notices)
    end)

    it("uses the configured repository, directory and default name", function()
      options = { repository = "someone/fork", dir = "/checkout" }
      release.html_url = "https://github.com/someone/fork/releases/tag/6.4.0"
      reload()
      wezterm._respond = respond
      check()
      local curl = find_command(is_curl)
      assert.equals("https://api.github.com/repos/someone/fork/releases/latest", curl[#curl])
      assert.equals("/checkout", wezterm._commands[1][3])
      assert.equals("someone/fork release", notices[1][1])
    end)

    it("rejects release links outside the repository", function()
      release.html_url = "https://example.com/releases/tag/6.4.0"
      check()
      assert.matches("Unexpected GitHub release response", wezterm._logs.warn[1], 1, true)
      assert.same({}, notices)
    end)

    it("logs a missing or non-version local tag without contacting GitHub", function()
      installed_tag = "experiment"
      check()
      assert.matches("is not a version", wezterm._logs.warn[1], 1, true)
      assert.is_nil(find_command(is_curl))
    end)

    for _, command in ipairs { "git", "curl" } do
      it("logs " .. command .. " failures and throttles retries", function()
        fail_command = command
        check()
        assert.matches("test failure", wezterm._logs.warn[1], 1, true)
        assert.same({}, notices)
        status()
        assert.same({}, wezterm._timers)
      end)
    end

    it("logs invalid JSON", function()
      wezterm.json_parse = function()
        error "invalid JSON"
      end
      check()
      assert.matches("invalid JSON", wezterm._logs.warn[1], 1, true)
      assert.same({}, notices)
    end)
  end)

  -- ── Unstable channel ──────────────────────────────────────────────────────

  describe("unstable channel", function()
    before_each(function()
      options.channel = "unstable"
      reload()
      wezterm._respond = respond
    end)

    it("checks the current branch tip without the GitHub API", function()
      check()
      assert.same({
        "git",
        "-c",
        "http.lowSpeedLimit=1",
        "-c",
        "http.lowSpeedTime=15",
        "ls-remote",
        "--exit-code",
        "https://github.com/sravioli/wezterm.git",
        "refs/heads/feat/v7.0.0",
      }, wezterm._commands[2])
      assert.same(
        { "git", "-C", "config dir", "merge-base", "--is-ancestor", remote_tip, "HEAD" },
        wezterm._commands[3]
      )
      assert.is_nil(find_command(is_curl))
      assert.equals("WezTerm config update", notices[1][1])
      assert.matches("feat/v7.0.0", notices[1][2], 1, true)
      assert.equals("https://github.com/sravioli/wezterm/commits/feat/v7.0.0", notices[1][3])
    end)

    it("stays silent when HEAD already contains the tip", function()
      merged = true
      check()
      assert.same({}, notices)
      assert.same({}, wezterm._logs.warn)
    end)

    it("checks the configured branch, even from a detached HEAD", function()
      options.branch = "main"
      branch = ""
      reload()
      wezterm._respond = respond
      check()
      assert.equals("refs/heads/main", wezterm._commands[1][#wezterm._commands[1]])
      assert.equals("https://github.com/sravioli/wezterm/commits/main", notices[1][3])
    end)

    it("skips a detached HEAD without a configured branch", function()
      branch = ""
      check()
      assert.equals(1, #wezterm._commands)
      assert.same({}, notices)
    end)

    it("notifies once per remote tip", function()
      check()
      wezterm.GLOBAL[state_key()] = { notified = state().notified }
      check()
      assert.equals(1, #notices)
      remote_tip = string.rep("c", 40)
      wezterm.GLOBAL[state_key()] = { notified = state().notified }
      check()
      assert.equals(2, #notices)
    end)

    it("logs a missing remote branch", function()
      fail_command = "git"
      check()
      assert.matches("test failure", wezterm._logs.warn[1], 1, true)
      assert.same({}, notices)
    end)
  end)

  -- ── check_now ─────────────────────────────────────────────────────────────

  describe("check_now", function()
    it("ignores the cooldown and repeats the notice", function()
      check()
      local notice = beacon.check_now(window)
      assert.equals("release:6.4.0", notice.key)
      assert.equals(2, #notices)
    end)

    it("reports when already up to date", function()
      release.tag_name = "6.3.4"
      release.html_url = "https://github.com/sravioli/wezterm/releases/tag/6.3.4"
      assert.is_nil(beacon.check_now(window))
      assert.same({ "WezTerm config", "Already up to date.", nil, 8000 }, notices[1])
    end)

    it("logs failures instead of raising", function()
      fail_command = "git"
      assert.is_nil(beacon.check_now(window))
      assert.matches("test failure", wezterm._logs.warn[1], 1, true)
    end)

    it("warns when called before setup", function()
      wezterm._reset()
      beacon = require "beacon.api"
      assert.is_nil(beacon.check_now(window))
      assert.matches("before setup", wezterm._logs.warn[1], 1, true)
    end)
  end)
end)
