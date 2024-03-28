-- 转换非中文标点

local M = {}

local vsel = require("infra.vsel")

local converter = require("punctconv.converter")

local api = vim.api

function M.multiline_vsel()
  local bufnr = api.nvim_get_current_buf()
  local range = vsel.range(bufnr)
  if range == nil then return end
  local lines = vsel.multiline_text(bufnr)
  if lines == nil then return end

  local result = {}
  local conv = converter()
  for _, line in ipairs(lines) do
    table.insert(result, table.concat(conv(line), ""))
  end

  api.nvim_buf_set_lines(bufnr, range.start_line, range.stop_line, true, result)
end

return M
