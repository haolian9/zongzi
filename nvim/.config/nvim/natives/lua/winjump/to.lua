local ni = require("infra.ni")

---jump to specific window on the current screen/tab by window-id
---@param winnr number @winnr is tabpage specific
return function(winnr)
  local winid = vim.fn.win_getid(winnr)

  if winid == 0 then return end

  ni.set_current_win(winid)
end
