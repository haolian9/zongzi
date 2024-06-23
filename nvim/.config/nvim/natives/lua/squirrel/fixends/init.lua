local M = {}

local ni = require("infra.ni")

local general = require("squirrel.fixends.general")

function M.lua()
  local winid = ni.get_current_win()
  return require("squirrel.fixends.lua")(winid) or general(winid)
end

function M.general()
  local winid = ni.get_current_win()
  return general(winid)
end

return M
