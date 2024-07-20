-- visual select relevant functions
--
-- supports v and V, but not ctrl-v
--
-- special position of <>
-- * nil       (0, 0; 0, 0)
-- * top-left: (1, 0; 1, 0)
-- * $
--
-- row: 1-based
-- col: 0-based

local M = {}

local buflines = require("infra.buflines")
local feedkeys = require("infra.feedkeys")
local ni = require("infra.ni")
local utf8 = require("infra.utf8")
local wincursor = require("infra.wincursor")

-- MAX_COL
M.max_col = 0x7fffffff

---@class infra.vsel.Range
---@field start_line number @0-indexed, inclusive
---@field start_col number @0-indexed, inclusive
---@field stop_line number @0-indexed, exclusive
---@field stop_col number @0-indexed, exclusive; -1 indicates EOL

---@param bufnr number
---@param calibrate? boolean @utf8
---@return infra.vsel.Range?
function M.range(bufnr, calibrate)
  bufnr = bufnr or ni.get_current_buf()
  if calibrate == nil then calibrate = false end

  --row: 1-based, inclusive; col: 0-based, inclusive
  local start_row, start_col = unpack(ni.buf_get_mark(bufnr, "<"))
  --NB: `>` mark always returns the first byte of multi-bytes rune
  --row: 1-based, inclusive; col: 0-based, inclusive
  local stop_row, stop_col = unpack(ni.buf_get_mark(bufnr, ">"))

  --fresh start, no select
  if start_row == 0 and start_col == 0 and stop_row == 0 and stop_col == 0 then return end

  --ensure start_row is always smaller then stop_row
  if start_row > stop_row then
    start_row, stop_row = stop_row, start_row
    start_col, stop_col = stop_col, start_col
  end

  if stop_col == M.max_col then
    stop_col = -1
  else
    if calibrate then
      local lnum = stop_row - 1
      local col = stop_col
      local lines = ni.buf_get_text(bufnr, lnum, col, lnum, col + 1, {})
      assert(#lines == 1 and #lines[1] == 1)
      local rune_len = utf8.rune_length(utf8.byte0(lines[1]))
      stop_col = stop_col + rune_len
      stop_col = stop_col - 1 --the stop_col it self
      stop_col = stop_col + 1 --the stop_col should be exclusive
    else
      stop_col = stop_col + 1
    end
  end

  return { start_line = start_row - 1, start_col = start_col, stop_line = stop_row - 1 + 1, stop_col = stop_col }
end

-- only support one line select
---@param bufnr? number
---@return string?
function M.oneline_text(bufnr)
  bufnr = bufnr or ni.get_current_buf()

  local range = M.range(bufnr, true)
  if range == nil then return end

  assert(range.start_line + 1 == range.stop_line, "more than one line")
  return buflines.partial_line(bufnr, range.start_line, range.start_col, range.stop_col)
end

---@param bufnr? number
---@return string[]?
function M.multiline_text(bufnr)
  bufnr = bufnr or ni.get_current_buf()

  local range = M.range(bufnr, true)
  if range == nil then return end

  return ni.buf_get_text(bufnr, range.start_line, range.start_col, range.stop_line - 1, range.stop_col, {})
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
