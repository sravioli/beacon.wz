---@module "beacon.mosaic.update"
---@author sravioli
---@license GNU-GPLv2

---mosaic integration `beacon.update`: shown while any watched repository has
---an update, as the number of repositories that can be updated. `beacon`
---logs which ones. mosaic reads this file only when a layout names it.
---
---Options (`options["beacon.update"]`):
---  icon? string|false  glyph before the text (default: oct_package, as lazy.nvim); false hides it

return {
  api = 1,
  new = function(opts)
    local wezterm = require "wezterm"
    local beacon = require "beacon.api"

    local icon = opts.icon
    if icon == nil then
      icon = (wezterm.nerdfonts or {}).oct_package or ""
    end

    return function()
      local updates = beacon.available()
      if #updates == 0 then
        return { enabled = false }
      end
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
        text = { enabled = true, value = tostring(#updates) },
      }
    end
  end,
}
