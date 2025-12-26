local M = {}

local ni = require("infra.ni")

local display_panes = require("winman.display_panes")

---jump to specific window on the current screen/tab by window-id
---@param winnr number @winnr is tabpage specific
function M.to(winnr)
  local winid = vim.fn.win_getid(winnr)
  if winid == 0 then return end
  ni.set_current_win(winid)
end

function M.display_panes()
  display_panes(function(winnr) M.to(winnr) end)
end

return M
