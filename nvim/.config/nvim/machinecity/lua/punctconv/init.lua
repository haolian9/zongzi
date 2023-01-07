-- 转换非中文标点

local M = {}

local vsel = require("infra.vsel")
local converter = require("punctconv.converter")

local api = vim.api

M.multiline_vsel = function()
  local bufnr = api.nvim_get_current_buf()
  local start_row, start_col, stop_row, stop_col = vsel.range(bufnr)
  if start_row == 0 and start_col == 0 and stop_row == 0 and stop_col == 0 then return end
  local lines = vsel.multiline_text(bufnr)
  if lines == nil then return end

  local result = {}
  local conv = converter()
  for _, line in ipairs(lines) do
    table.insert(result, table.concat(conv(line), ""))
  end

  api.nvim_buf_set_lines(bufnr, start_row - 1, stop_row, true, result)
end

return M
