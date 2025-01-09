local Ephemeral = require("infra.Ephemeral")
local itertools = require("infra.itertools")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")

local nuts = require("squirrel.nuts")
local facts = require("squirrel.whereami.facts")

return function(filetype)
  local host_winid = ni.get_current_win()
  if filetype == nil then
    local host_bufnr = ni.win_get_buf(host_winid)
    filetype = prefer.bo(host_bufnr, "filetype")
  end

  local route
  if filetype == "c" then
    route = require("squirrel.whereami.c")(host_winid)
  elseif filetype == "lua" then
    route = require("squirrel.whereami.lua")(host_winid)
  else
    error("unsupported filetype")
  end

  local line = string.format("🌳%s🌳", route)

  local bufnr = Ephemeral({ namepat = "squirrel://whereami/{bufnr}" }, { line })

  local winopts = { relative = "cursor", row = -1, col = 0, width = #line, height = 1 }
  local winid = rifts.open.win(bufnr, false, winopts)
  ni.win_set_hl_ns(winid, facts.floatwin_ns)

  vim.defer_fn(function()
    if not ni.win_is_valid(winid) then return end
    ni.win_close(winid, false)
  end, 1000 * 2)
end
