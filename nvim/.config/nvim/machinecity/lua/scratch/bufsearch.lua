local M = {}

local api = vim.api
local vsel = require("infra.vsel")
local jelly = require("infra.jellyfish")("scratch.bufsearch")

local state = {
  ns = api.nvim_create_namespace("scratch.bufsearch"),
  last_search = nil,
}

local function via_extmark(bufnr, pattern)
  assert(bufnr ~= nil and pattern ~= nil)

  if state.last_search ~= nil then
    api.nvim_buf_clear_namespace(bufnr, state.ns, 0, -1)
    local same_search = pattern == state.last_search
    state.last_search = nil
    if same_search then return end
  end

  local l0 = 0
  local l9 = vim.api.nvim_buf_line_count(bufnr) - 1
  local matcher = vim.regex(pattern)
  local count = 0

  for i = l0, l9 do
    local line = api.nvim_buf_get_lines(bufnr, i, i + 1, true)[1]
    local offset = 0
    while #line > 0 do
      -- 1-based
      local m1, m10 = matcher:match_str(line)
      if m1 == nil then break end
      count = count + 1
      api.nvim_buf_add_highlight(bufnr, state.ns, "Search", i, offset + m1, offset + m10)
      offset = offset + m10
      line = string.sub(line, m10 + 1)
    end
  end

  if count > 0 then state.last_search = pattern end
  jelly.info("matched %d result", count)
end

function M.vsel(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  local pattern = vsel.oneline_escaped(bufnr)
  if pattern == nil then return end

  via_extmark(bufnr, pattern)
end

function M.cword(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  local keyword = vim.fn.expand("<cword>")
  if keyword == "" then return end

  via_extmark(bufnr, keyword)
end

function M.clear(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  api.nvim_buf_clear_namespace(bufnr, state.ns, 0, -1)
end

return M
