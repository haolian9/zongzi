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

local feedkeys = require("infra.feedkeys")
local ni = require("infra.ni")
local strlib = require("infra.strlib")
local utf8 = require("infra.utf8")
local wincursor = require("infra.wincursor")

-- MAX_COL
M.max_col = 0x7fffffff

---@class infra.vsel.Range
---@field start_line number @0-indexed, inclusive
---@field start_col number @0-indexed, inclusive
---@field stop_line number @0-indexed, exclusive
---@field stop_col number @0-indexed, exclusive

---@param bufnr number
---@return infra.vsel.Range?
function M.range(bufnr)
  assert(strlib.startswith(ni.get_mode().mode, "n"))

  bufnr = bufnr or ni.get_current_buf()

  local start_row, start_col = unpack(ni.buf_get_mark(bufnr, "<"))
  --NB: `>` mark returns the position of first byte of multi-bytes rune
  local stop_row, stop_col = unpack(ni.buf_get_mark(bufnr, ">"))

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
  bufnr = bufnr or ni.get_current_buf()

  local range = M.range(bufnr)
  if range == nil then return end

  -- not same row
  if range.start_line + 1 ~= range.stop_line then return end

  -- shortcut
  if range.stop_col - 1 == M.max_col then return ni.buf_get_text(bufnr, range.start_line, range.start_col, range.start_line, -1, {})[1] end

  local chars
  do
    local stop_col = range.stop_col + utf8.maxbytes
    local lines = ni.buf_get_text(bufnr, range.start_line, range.start_col, range.start_line, stop_col, {})
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

---@param bufnr ?number
---@return table|nil
function M.multiline_text(bufnr)
  bufnr = bufnr or ni.get_current_buf()

  local range = M.range(bufnr)
  if range == nil then return end

  -- shortcut
  if range.stop_col - 1 == M.max_col then return ni.buf_get_text(bufnr, range.start_line, range.start_col, range.stop_line - 1, -1, {}) end

  local lines
  do
    local stop_col = range.stop_col + utf8.maxbytes - 1
    lines = ni.buf_get_text(bufnr, range.start_line, range.start_col, range.stop_line - 1, stop_col, {})
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
  wincursor.go(winid, start_line, start_col)
  -- 'o' is necessary for the case when nvim is already in visual mode before calling this function
  feedkeys.codes("vo", "nx")
  wincursor.go(winid, stop_line - 1, stop_col - 1)
end

---select lines between start and stop
---place cursor on the begin of the last line
---@param winid integer
---@param start_line number @0-indexed, inclusive
---@param stop_line  number @0-indexed, exclusive
function M.select_lines(winid, start_line, stop_line)
  wincursor.go(winid, start_line, 0)
  -- 'o' is necessary for the case when nvim is already in visual mode before calling this function
  feedkeys.codes("Vo", "nx")
  wincursor.go(winid, stop_line - 1, 0)
end

---usually used after buflines.replaces
---this exists for https://github.com/neovim/neovim/issues/24007
---@param bufnr integer
---@param range infra.vsel.Range
function M.restore_gv(bufnr, range)
  ni.buf_set_mark(bufnr, "<", range.start_line + 1, range.start_col, {})
  ni.buf_set_mark(bufnr, ">", range.stop_line + 1 - 1, range.stop_col - 1, {})
end

return M
