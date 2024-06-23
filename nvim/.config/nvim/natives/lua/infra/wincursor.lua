local M = {}

local augroups = require("infra.augroups")
local buflines = require("infra.buflines")
local jelly = require("infra.jellyfish")("infra.wincursor", "debug")
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

  function M.last_position(winid)
    assert(winid ~= 0)
    winid = winid or ni.get_current_win()
    local tuple = assert(lasts[winid])
    return { lnum = tuple[1] - 1, col = tuple[2], row = tuple[1] }
  end
end

---of current or given winid
---@param winid? integer @nil=current win
---@return integer @1-based
function M.row(winid)
  winid = winid or ni.get_current_win()
  return ni.win_get_cursor(winid)[1]
end

---of current or given winid
---@param winid? integer @nil=current win
---@return integer @0-based
function M.lnum(winid)
  winid = winid or ni.get_current_win()
  return M.row(winid) - 1
end

---of current or given winid
---@param winid? integer @nil=current win
---@return integer @0-based
function M.col(winid)
  winid = winid or ni.get_current_win()
  return ni.win_get_cursor(winid)[2]
end

---of current or given winid
---@param winid? integer @nil=current win
---@return {lnum: integer, col: integer, row: integer}
function M.position(winid)
  winid = winid or ni.get_current_win()
  local tuple = ni.win_get_cursor(winid)
  return { lnum = tuple[1] - 1, col = tuple[2], row = tuple[1] }
end

---of current or given winid
---@param winid? integer @nil=current win
---@return integer,integer @row,col
function M.rc(winid)
  winid = winid or ni.get_current_win()
  return unpack(ni.win_get_cursor(winid))
end

---of current or given winid
---@param winid? integer @nil=current win
---@return integer,integer @row,col
function M.lc(winid)
  winid = winid or ni.get_current_win()
  local tuple = ni.win_get_cursor(winid)
  return tuple[1] - 1, tuple[2]
end

---move the cursor of current or given winid
---@param winid? integer
---@param lnum integer @0-based
---@param col integer @0-based
function M.go(winid, lnum, col)
  winid = winid or ni.get_current_win()
  ni.win_set_cursor(winid, { lnum + 1, col })
end

---move the cursor of current or given winid
---@param winid? integer
---@param row integer @1-based
---@param col integer @0-based
function M.g1(winid, row, col)
  winid = winid or ni.get_current_win()
  ni.win_set_cursor(winid, { row, col })
end

---like 'tail -f': move the cursor to the last line
---NB: incompatible with &wrap
---@param winid integer
function M.follow(winid)
  if prefer.wo(winid, "wrap") then jelly.warn("wincursor.follow wont work correctly with &wrap on") end

  local bufnr = ni.win_get_buf(winid)

  local high = buflines.high(bufnr)
  M.go(winid, high, 0)

  local height = ni.win_get_height(winid)
  local toplnum = math.max(high - height + 1, 0)
  unsafe.win_set_toplnum(winid, toplnum)
end

return M
