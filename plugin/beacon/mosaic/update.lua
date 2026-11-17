---@module "beacon.mosaic.update"
---@author sravioli
---@license GNU-GPLv2

---mosaic integration `beacon.update`: shown while any watched repository has
---an update, as the number of repositories that can be updated. `beacon`
---logs which ones. mosaic reads this file only when a layout names it.
---
---Options (`options["beacon.update"]`):
---  icon? string|false  glyph before the text (default: sigil's `Status.update`, oct_package as
---                       in lazy.nvim); false hides it

return {
  api = 1,
  new = function(opts)
    local beacon = require "beacon.api"

    local icon = opts.icon
    if icon == nil then
      local sigil = require("beacon.deps").optional "sigil"
      local ok, glyph = pcall(function()
        return sigil and sigil.symbol "Status.update"
      end)
      if ok and type(glyph) == "string" then
        icon = glyph
      else
        icon = (require("wezterm").nerdfonts or {}).oct_package or ""
      end
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
