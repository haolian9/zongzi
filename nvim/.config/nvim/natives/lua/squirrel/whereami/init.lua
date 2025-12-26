local Ephemeral = require("infra.Ephemeral")
local ni = require("infra.ni")
local oop = require("infra.oop")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")

local facts = require("squirrel.whereami.facts")

local routers = oop.lazyattrs({}, function(ft)
  local modname = "squirrel.whereami." .. ft
  return require(modname)
end)

return function(ft)
  local host_winid = ni.get_current_win()
  if ft == nil then --
    ft = prefer.bo(ni.win_get_buf(host_winid), "filetype")
  end

  local route = assert(routers[ft])(host_winid)
  local line = string.format("🌳%s🌳", route)

  local bufnr = Ephemeral({ namepat = "squirrel://whereami/{bufnr}" }, { line })

  local winopts = { relative = "cursor", row = -1, col = 0, width = #line, height = 1 }
  local winid = rifts.open.win(bufnr, false, winopts)
  ni.win_set_hl_ns(winid, facts.floatwin_ns)

  vim.defer_fn(function()
    if not ni.win_is_valid(winid) then return end
    ni.win_close(winid, false)
  end, 1000 * 3)
end
