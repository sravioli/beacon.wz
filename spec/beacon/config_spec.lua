local wezterm = require "wezterm"

describe("beacon.config", function()
  local config

  before_each(function()
    wezterm._reset()
    config = require "beacon.config"
  end)

  it("fills in defaults", function()
    assert.same({
      repository = "owner/repo",
      dir = "config dir",
      channel = "stable",
      interval_seconds = 86400,
      delay_seconds = 5,
      name = "owner/repo",
      timeout_ms = 8000,
      notify = true,
    }, config.resolve { repository = "owner/repo" })
    assert.is_false(config.resolve({ repository = "owner/repo", notify = false }).notify)
  end)

  it("keeps explicit options", function()
    local cfg = config.resolve {
      repository = "some-one/my.repo_x",
      dir = "/checkout",
      channel = "unstable",
      branch = "main",
      interval_hours = 2.5,
      delay_seconds = 0,
      name = "My config",
      timeout_ms = 3000,
    }
    assert.equals("/checkout", cfg.dir)
    assert.equals("unstable", cfg.channel)
    assert.equals("main", cfg.branch)
    assert.equals(9000, cfg.interval_seconds)
    assert.equals(0, cfg.delay_seconds)
    assert.equals("My config", cfg.name)
    assert.equals(3000, cfg.timeout_ms)
  end)

  it("enforces a one-hour interval floor", function()
    local cfg = config.resolve { repository = "o/r", interval_hours = 0 }
    assert.equals(3600, cfg.interval_seconds)
  end)

  it("warns about unknown options", function()
    config.resolve { repository = "o/r", interval_hour = 2 }
    assert.equals(1, #wezterm._logs.warn)
    assert.matches("interval_hour", wezterm._logs.warn[1], 1, true)
  end)

  for _, case in ipairs {
    { nil, "Options must be a table" },
    { {}, "repository" },
    { { repository = "not a repo" }, "repository" },
    { { repository = "o/r/x" }, "repository" },
    { { repository = "o/r", channel = "nightly" }, "channel" },
    { { repository = "o/r", interval_hours = -1 }, "interval_hours" },
    { { repository = "o/r", delay_seconds = "5" }, "delay_seconds" },
    { { repository = "o/r", branch = "" }, "branch" },
    { { repository = "o/r", dir = 1 }, "dir" },
  } do
    it("rejects " .. case[2], function()
      local ok, err = pcall(config.resolve, case[1])
      assert.is_false(ok)
      assert.matches(case[2], err, 1, true)
    end)
  end

  it("skips validation and never loads warden when validate = false", function()
    local deps = require "beacon.deps"
    local real = deps.warden
    finally(function()
      deps.warden = real
    end)
    deps.warden = function()
      error "warden loaded"
    end
    local cfg = config.resolve { repository = "not a repo", validate = false }
    assert.equals("not a repo", cfg.repository)
  end)
end)
