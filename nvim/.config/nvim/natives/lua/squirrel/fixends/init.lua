local M = {}

local ni = require("infra.ni")
local oop = require("infra.oop")

---@type table<string,fun(winid:integer):true?>
local solutions = oop.lazyattrs({}, function(key)
  local modname = string.format("squirrel.fixends.%s", key)
  return require(modname)
end)

function M.lua()
  local winid = ni.get_current_win()

  return solutions.postfix_op(winid) --
    or solutions.lua(winid) --
    or solutions.general(winid)
end

function M.general()
  local winid = ni.get_current_win()

  return solutions.postfix_op(winid) --
    or solutions.general(winid)
end

return M
