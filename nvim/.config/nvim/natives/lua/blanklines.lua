local M = {}

local listlib = require("infra.listlib")
local ni = require("infra.ni")
local repeats = require("infra.repeats")

function M.below()
  ni.put(listlib.zeros(vim.v.count1, ""), "l", true, false)
  repeats.remember_redo(ni.get_current_buf(), M.below)
end

function M.above()
  ni.put(listlib.zeros(vim.v.count1, ""), "l", false, false)
  repeats.remember_redo(ni.get_current_buf(), M.above)
end

return M
