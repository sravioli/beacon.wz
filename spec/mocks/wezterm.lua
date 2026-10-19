--- Hand-written WezTerm mock. Specs drive child processes through `wezterm._respond`.

local M = {}

-- Minimal warp.wz stand-in so specs run without sibling checkouts (CI).
local warp = {
  process = {
    run = function(argv)
      local ok, success, stdout, stderr = pcall(M.run_child_process, argv)
      if not ok then
        return false, "", tostring(success)
      end
      return success == true, stdout or "", stderr or ""
    end,
  },
}

---Reset all recorded state and remove cached beacon modules.
function M._reset()
  M.GLOBAL = {}
  M.config_dir = "config dir"
  M._handlers = {}
  M._timers = {}
  M._commands = {}
  M._logs = { info = {}, warn = {}, error = {} }
  M._respond = function(args)
    error("unexpected command " .. table.concat(args, " "))
  end
  M._json = {}
  M._warp = warp
  M.plugin = {
    require = function(url)
      if url:find("warp.wz", 1, true) and M._warp then
        return M._warp
      end
      error("plugin.require disabled in specs: " .. tostring(url))
    end,
  }
  M.json_parse = function(text)
    local value = M._json[text]
    if value == nil then
      error "invalid JSON"
    end
    return value
  end
  for name in pairs(package.loaded) do
    if name == "beacon" or name:match "^beacon%." then
      package.loaded[name] = nil
    end
  end
end

function M.on(event, callback)
  M._handlers[event] = M._handlers[event] or {}
  table.insert(M._handlers[event], callback)
end

---Emit an event to every registered handler.
function M._emit(event, ...)
  for _, callback in ipairs(M._handlers[event] or {}) do
    callback(...)
  end
end

M.time = {
  call_after = function(delay, callback)
    table.insert(M._timers, { delay = delay, callback = callback })
  end,
}

---Run the oldest pending timer.
function M._fire()
  local timer = table.remove(M._timers, 1)
  assert(timer, "no pending timer")
  timer.callback()
end

function M.run_child_process(args)
  table.insert(M._commands, args)
  return M._respond(args)
end

for _, level in ipairs { "info", "warn", "error" } do
  M["log_" .. level] = function(message)
    table.insert(M._logs[level], message)
  end
end

M._reset()
package.loaded.wezterm = M

return M
