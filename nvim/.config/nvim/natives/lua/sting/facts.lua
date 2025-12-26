local M = {}

local highlighter = require("infra.highlighter")

do
  M.preview_hi = "StingPreviewCursorLine"

  local hi = highlighter(0)
  if vim.go.background == "light" then
    hi(M.preview_hi, { fg = 1 })
  else
    hi(M.preview_hi, { fg = 9 })
  end
end

return M
