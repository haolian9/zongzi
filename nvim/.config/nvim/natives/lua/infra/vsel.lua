-- visual select relevant functions
--
-- special position of <>
-- * nil       (0, 0; 0, 0)
-- * top-left: (1, 0; 1, 0)
-- * $
--
-- row: 1-based
-- col: 0-based

local M = {}

local strlib = require("infra.strlib")
local utf8 = require("infra.utf8")

local api = vim.api

-- MAX_COL
M.max_col = 0x7fffffff

---@class infra.vsel.Range
---@field start_line number @0-indexed, inclusive
---@field start_col number @0-indexed, inclusive
---@field stop_line number @0-indexed, exclusive
---@field stop_col number @0-indexed, exclusive

--NB: it only works in normal mode
--no plans to use line/col('v') here so far
--* start_line 0-based, inclusive
--* start_col  0-based, inclusive
--* stop_line  0-based, exclusive
--* stop_col   0-based, exclusive
---@param bufnr number
---@return infra.vsel.Range?
function M.range(bufnr)
  assert(strlib.startswith(api.nvim_get_mode().mode, "n"))

  bufnr = bufnr or api.nvim_get_current_buf()

  local start_row, start_col = unpack(api.nvim_buf_get_mark(bufnr, "<"))
  --NB: `>` mark returns the position of first byte of multi-bytes rune
  local stop_row, stop_col = unpack(api.nvim_buf_get_mark(bufnr, ">"))

  --fresh start, no select
  if start_row == 0 and start_col == 0 and stop_row == 0 and stop_col == 0 then return end

  --start_row is always smaller then stop_row
  if start_row > stop_row then
    start_row, stop_row = stop_row, start_row
    start_col, stop_col = stop_col, start_col
  end

  return {
    start_line = start_row - 1,
    start_col = start_col,
    stop_line = stop_row,
    stop_col = stop_col + 1,
  }
end

-- only support one line select
---@param bufnr ?number
---@return nil|string
function M.oneline_text(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  local range = M.range(bufnr)
  if range == nil then return end

  -- not same row
  if range.start_line + 1 ~= range.stop_line then return end

  -- shortcut
  if range.stop_col - 1 == M.max_col then return api.nvim_buf_get_text(bufnr, range.start_line, range.start_col, range.start_line, -1, {})[1] end

  local chars
  do
    local stop_col = range.stop_col + utf8.maxbytes
    local lines = api.nvim_buf_get_text(bufnr, range.start_line, range.start_col, range.start_line, stop_col, {})
    assert(#lines == 1)
    chars = lines[1]
  end

  local text
  do
    local sel_len = range.stop_col - range.start_col
    -- multi-bytes utf-8 rune
    local byte0 = utf8.byte0(chars, sel_len)
    local rune_len = utf8.rune_length(byte0)
    text = chars:sub(1, sel_len + rune_len - 1)
  end

  return text
end

-- according to `:h magic`
---@param bufnr ?number
---@return nil|string
function M.oneline_escaped(bufnr)
  local raw = M.oneline_text(bufnr)
  if raw == nil then return end
  return vim.fn.escape(raw, [[.*~$/()]])
end

---@param bufnr ?number
---@return table|nil
function M.multiline_text(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  local range = M.range(bufnr)
  if range == nil then return end

  -- shortcut
  if range.stop_col - 1 == M.max_col then return api.nvim_buf_get_text(bufnr, range.start_line, range.start_col, range.stop_line - 1, -1, {}) end

  local lines
  do
    local stop_col = range.stop_col + utf8.maxbytes - 1
    lines = api.nvim_buf_get_text(bufnr, range.start_line, range.start_col, range.stop_line - 1, stop_col, {})
  end

  -- handles last line
  do
    local chars = lines[#lines]
    local sel_len = range.stop_col
    -- multi-bytes utf-8 rune
    local byte0 = utf8.byte0(chars, sel_len)
    local rune_len = utf8.rune_length(byte0)
    lines[#lines] = chars:sub(1, sel_len + rune_len - 1)
  end

  return lines
end

---select a region
---@param winid integer
---@param start_line number @0-indexed, inclusive
---@param start_col  number @0-indexed, inclusive
---@param stop_line  number @0-indexed, exclusive
---@param stop_col   number @0-indexed, exclusive
function M.select_region(winid, start_line, start_col, stop_line, stop_col)
  api.nvim_win_set_cursor(winid, { start_line + 1, start_col })
  -- 'o' is necessary for the case when nvim is already in visual mode before calling this function
  api.nvim_feedkeys("vo", "nx", false)
  api.nvim_win_set_cursor(winid, { stop_line + 1 - 1, stop_col - 1 })
end

---select lines between start and stop
---place cursor on the begin of the last line
---@param winid integer
---@param start_line number @0-indexed, inclusive
---@param stop_line  number @0-indexed, exclusive
function M.select_lines(winid, start_line, stop_line)
  api.nvim_win_set_cursor(winid, { start_line + 1, 0 })
  -- 'o' is necessary for the case when nvim is already in visual mode before calling this function
  api.nvim_feedkeys("Vo", "nx", false)
  api.nvim_win_set_cursor(winid, { stop_line + 1 - 1, 0 })
end

return M
