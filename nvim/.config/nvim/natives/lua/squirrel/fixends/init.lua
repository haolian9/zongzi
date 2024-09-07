local M = {}

local ni = require("infra.ni")

local general = require("squirrel.fixends.general")
local postfix_op = require("squirrel.fixends.postfix_op")

function M.lua()
  local winid = ni.get_current_win()

  return postfix_op(winid) --
    or require("squirrel.fixends.lua")(winid) --
    or general(winid)
end

function M.general()
  local winid = ni.get_current_win()

  return postfix_op(winid) --
    or general(winid)
end

return M
