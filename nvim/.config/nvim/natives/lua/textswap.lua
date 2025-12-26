local M = {}

local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("textswap", "debug")
local ni = require("infra.ni")
local unsafe = require("infra.unsafe")
local vsel = require("infra.vsel")
local wincursor = require("infra.wincursor")

local xmarks = {}
do
  local ns = ni.create_namespace("textswap.extmarks")

  ---@param bufnr integer
  ---@param range infra.vsel.Range
  ---@return integer xmid
  function xmarks.set(bufnr, range, hi)
    return ni.buf_set_extmark(bufnr, ns, range.start_line, range.start_col, {
      end_row = range.stop_line - 1,
      end_col = range.stop_col,
      hl_group = hi,
      right_gravity = false,
      end_right_gravity = true,
    })
  end

  ---@param bufnr integer
  ---@param xmid integer
  function xmarks.del(bufnr, xmid) ni.buf_del_extmark(bufnr, ns, xmid) end

  ---@param bufnr integer
  ---@param xmid integer
  ---@return infra.vsel.Range?
  function xmarks.range(bufnr, xmid)
    local xm = ni.buf_get_extmark_by_id(bufnr, ns, xmid, { details = true })
    if #xm == 0 then return end

    return {
      start_line = xm[1],
      start_col = xm[2],
      stop_line = xm[3].end_row + 1, --0-based; exclusive
      stop_col = xm[3].end_col, --0-based; exclusive
    }
  end
end

---@param bufnr integer
---@param range infra.vsel.Range
---@return string[]
local function text_from_range(bufnr, range) --
  return ni.buf_get_text(bufnr, range.start_line, range.start_col, range.stop_line - 1, range.stop_col, {})
end

---@param bufnr integer
---@param range infra.vsel.Range
---@param text string[]
local function range_become_text(bufnr, range, text) --
  ni.buf_set_text(bufnr, range.start_line, range.start_col, range.stop_line - 1, range.stop_col, text)
end

---@param src {bufnr:integer,xmid:integer}
---@param dest {bufnr:integer,xmid:integer}
local function swap(src, dest)
  if not ni.buf_is_valid(src.bufnr) then return jelly.warn("src bufnr is invalid") end

  local src_range = xmarks.range(src.bufnr, src.xmid)
  if src_range == nil then return jelly.warn("src xmark is gone") end
  xmarks.del(src.bufnr, src.xmid)

  local src_text = text_from_range(src.bufnr, src_range)
  local dest_text = text_from_range(dest.bufnr, assert(xmarks.range(dest.bufnr, dest.xmid)))
  if itertools.equals(src_text, dest_text) then return jelly.info("src and dest are the same") end

  range_become_text(src.bufnr, src_range, dest_text)

  --dest range may change after src text changed
  local dest_range = xmarks.range(dest.bufnr, dest.xmid)
  if dest_range == nil then return jelly.warn("dest xmark is gone") end
  xmarks.del(dest.bufnr, dest.xmid)

  range_become_text(dest.bufnr, dest_range, src_text)

  --stylua: ignore start
  jelly.info(
    "swapped src=#%d;%d:%d;%d:%d dest=#%d;%d:%d;%d:%d",
    src.bufnr, src_range.start_line, src_range.start_col, src_range.stop_line, src_range.stop_col,
    dest.bufnr, dest_range.start_line, dest_range.start_col, dest_range.stop_line, dest_range.stop_col
  )
  --stylua: ignore end
end

local state = {
  src = nil, ---@type nil|{bufnr:integer, xmid:integer}
}

function M.swap()
  local winid = ni.get_current_win()
  local cursor = wincursor.last_position(winid)
  local bufnr = ni.win_get_buf(winid)
  local range = vsel.range(bufnr, true)
  if range == nil then return jelly.info("no selecting range") end
  --since buf_set_xmark.end_col does not accept -1 or max_col
  if range.stop_col == -1 then range.stop_col = assert(unsafe.linelen(bufnr, range.stop_line - 1)) end

  if state.src == nil then
    local xmid = xmarks.set(bufnr, range, "Search")
    state.src = { bufnr = bufnr, xmid = xmid }
    jelly.info("source marked")
  else
    local xmid = xmarks.set(bufnr, range)
    local dest = { bufnr = bufnr, xmid = xmid }
    swap(state.src, dest)
    state.src = nil
  end

  --keep the cursor where it was: https://github.com/tommcdo/vim-exchange/issues/56
  wincursor.go(winid, cursor.lnum, cursor.col)
end

function M.cancel()
  local src = state.src
  if src == nil then return end
  state.src = nil
  xmarks.del(src.bufnr, src.xmid)
end

return M
