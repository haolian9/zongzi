local M = {}

M.coordinates = function(width_percent, height_percent)
  assert(width_percent < 1 and height_percent < 1)

  -- stole from plenary.window.float
  local width = math.floor(vim.o.columns * width_percent)
  local height = math.floor(vim.o.lines * height_percent)

  local top_row = math.floor(((vim.o.lines - height) / 2) - 1)
  local left_col = math.floor((vim.o.columns - width) / 2)

  return width, height, top_row, left_col
end

return M
