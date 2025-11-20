local M = {}

---@param width number @0-1, 1-n
---@param height number @0-1, 1-n
---@param horizontal? 'mid'|'left'|'right' @nil=mid
---@param vertical? 'mid'|'top'|'bot' @nil=mid
---@return { col: integer, row: integer, width: integer, height: integer }
function M.editor(width, height, horizontal, vertical, border)
  horizontal = horizontal or "mid"
  vertical = vertical or "mid"
  border = border or 0
  assert(border < 3)

  --concern: statusline and tabline matter too?

  local cols, lines = vim.go.columns, vim.go.lines

  local w = width < 1 and math.floor(cols * width) or width
  w = math.min(w, cols - border * 2)

  local h = height < 1 and math.floor(lines * height) or height
  h = math.min(h, lines - border * 2)

  local x
  if horizontal == "mid" then
    x = math.floor((cols - w) / 2)
  elseif horizontal == "left" then
    x = 0
  elseif horizontal == "right" then
    x = cols - w
  else
    error("unreachable")
  end

  local y
  if vertical == "mid" then
    y = math.floor((lines - h) / 2) - vim.go.cmdheight
  elseif vertical == "top" then
    y = 0
  elseif vertical == "bot" then
    y = lines - h - vim.go.cmdheight
  else
    error("unreachable")
  end

  return { col = x, row = y, width = w, height = h }
end

function M.fullscreen(border)
  border = border or 0
  assert(border < 3)

  local width = vim.go.columns - border * 2
  local height = vim.go.lines - vim.go.cmdheight - border * 2 -- cmdline
  return { col = 0, row = 0, width = width, height = height }
end

return M
