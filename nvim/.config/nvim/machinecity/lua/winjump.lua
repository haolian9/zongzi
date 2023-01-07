-- jump to specific window on the current screen/tab by window-id

local M = {}

---@param winnr number @winnr is tabpage specific
M.to = function(winnr)
  local win_id = vim.fn.win_getid(winnr)

  if win_id == 0 then return end

  vim.api.nvim_set_current_win(win_id)
end

return M
