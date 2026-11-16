---@module "beacon.mosaic.update"
---@author sravioli
---@license GNU-GPLv2

---mosaic integration `beacon.update`: shown while any watched repository has
---an update. One update shows its version; several show how many. mosaic
---reads this file only when a layout names it.
---
---Options (`options["beacon.update"]`):
---  icon? string|false  glyph before the text (default: oct_package, as lazy.nvim); false hides it
---  label? string       shown for a single update without a version (default: "update")

return {
  api = 1,
  new = function(opts)
    local wezterm = require "wezterm"
    local beacon = require "beacon.api"

    local icon = opts.icon
    if icon == nil then
      icon = (wezterm.nerdfonts or {}).oct_package or ""
    end
    local fallback = opts.label or "update"

    return function()
      local updates = beacon.available()
      if #updates == 0 then
        return { enabled = false }
      end
      local text = #updates == 1 and (updates[1].version or fallback) or tostring(#updates)
      return {
        enabled = true,
        cond = true,
        can_hide = true,
        padding = { left = 1 },
        accent = 4, -- colour hint; the preset styles the module
        icon = {
          enabled = icon ~= false and icon ~= "",
          value = icon or "",
          padding = { right = 1 },
        },
        text = { enabled = true, value = text },
      }
    end
  end,
}
