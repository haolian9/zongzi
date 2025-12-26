local M = {}

local augroups = require("infra.augroups")
local buflines = require("infra.buflines")
local jelly = require("infra.jellyfish")("infra.wincursor", "info")
local mi = require("infra.mi")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local unsafe = require("infra.unsafe")

do
  ---{winid: (row,col)}
  ---@type {[integer]: [integer,integer]}
  local lasts = {}

  function M.init()
    M.init = nil

    local aug = augroups.Augroup("wincursor://lasts")
    aug:repeats("CursorMoved", {
      callback = function(args)
        local winid = ni.get_current_win()
        assert(ni.win_get_buf(winid) == args.buf)
        local cursor = ni.win_get_cursor(winid)
        lasts[winid] = cursor
      end,
    })
  end

  ---@param winid? integer
  ---@return infra.wincursor.Position
  function M.last_position(winid)
    winid = mi.resolve_winid_param(winid)
    local tuple = assert(lasts[winid])
    return { lnum = tuple[1] - 1, col = tuple[2], row = tuple[1] }
  end
end

---of current or given winid
---@param winid? integer
---@return integer @1-based
function M.row(winid)
  winid = mi.resolve_winid_param(winid)
  return ni.win_get_cursor(winid)[1]
end

---of current or given winid
---@param winid? integer
---@return integer @0-based
function M.lnum(winid)
  winid = mi.resolve_winid_param(winid)
  return M.row(winid) - 1
end

---of current or given winid
---@param winid? integer
---@return integer @0-based
function M.col(winid)
  winid = mi.resolve_winid_param(winid)
  return ni.win_get_cursor(winid)[2]
end

---@class infra.wincursor.Position
---@field lnum integer
---@field col integer
---@field row integer

---of current or given winid
---@param winid? integer
---@return infra.wincursor.Position
function M.position(winid)
  winid = mi.resolve_winid_param(winid)
  local tuple = ni.win_get_cursor(winid)
  return { lnum = tuple[1] - 1, col = tuple[2], row = tuple[1] }
end

---of current or given winid
---@param winid? integer
---@return integer,integer @row,col
function M.rc(winid)
  winid = mi.resolve_winid_param(winid)
  return unpack(ni.win_get_cursor(winid))
end

---of current or given winid
---@param winid? integer
---@return integer,integer @row,col
function M.lc(winid)
  winid = mi.resolve_winid_param(winid)
  local tuple = ni.win_get_cursor(winid)
  return tuple[1] - 1, tuple[2]
end

---move the cursor of current or given winid
---@param winid? integer
---@param lnum integer @0-based
---@param col integer @0-based
function M.go(winid, lnum, col)
  winid = mi.resolve_winid_param(winid)
  ni.win_set_cursor(winid, { lnum + 1, col })
end

---move the cursor of current or given winid
---@param winid? integer
---@param row integer @1-based
---@param col integer @0-based
function M.g1(winid, row, col)
  winid = mi.resolve_winid_param(winid)
  ni.win_set_cursor(winid, { row, col })
end

---move the cursor to the last line of the buffer,
---and keep it at the bottom of the window
---NB: incompatible with &wrap
---@param winid integer
---@param cursor 'stay'|'eol'|'bol'
function M.follow(winid, cursor)
  if cursor == nil then cursor = "stay" end

  assert(not prefer.wo(winid, "wrap"))

  local bufnr = ni.win_get_buf(winid)
  local high = buflines.high(bufnr)

  --re-place cursor
  if cursor == "eol" then
    local col = cursor and assert(unsafe.linelen(bufnr, high)) or 0
    M.go(winid, high, col)
  elseif cursor == "bol" then
    local col = cursor and assert(unsafe.linelen(bufnr, high)) or 0
    M.go(winid, high, col)
  else
    assert(cursor == "stay")
  end

  do --bottom of the win
    local height = ni.win_get_height(winid)
    local toplnum = math.max(high - height + 1, 0)
    unsafe.win_set_toplnum(winid, toplnum)
  end
end

---@param winid integer
function M.zz(winid)
  local half = math.floor(ni.win_get_height(winid) / 2)
  local lnum = M.lnum(winid)
  local toplnum = math.max(lnum - half, 0)
  unsafe.win_set_toplnum(winid, toplnum)
end

---for cursor in current window only
---@return infra.wincursor.Position
function M.screenpos()
  --relevant UI
  --* terminal buffers
  --* conceal on
  --* &number, signcolumn
  --* tabline
  --* todo: winbar
  local orig_row, orig_col = unpack(ni.win_get_position(0))
  local win_row = vim.fn.winline()
  local win_col = vim.fn.wincol()

  local lnum = orig_row + (win_row - 1)
  local col = orig_col + (win_col - 1)
  local row = lnum + 1

  return { lnum = lnum, row = row, col = col }
end

return M
