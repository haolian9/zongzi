local M = {}

local general = require("squirrel.fixends.general")

local api = vim.api

function M.lua()
  local winid = api.nvim_get_current_win()
  return require("squirrel.fixends.lua")(winid) or general(winid)
end

function M.general()
  local winid = api.nvim_get_current_win()
  return general(winid)
end

return M
