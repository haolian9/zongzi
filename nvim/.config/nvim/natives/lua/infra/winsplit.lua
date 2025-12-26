local ex = require("infra.ex")
local mi = require("infra.mi")
local ni = require("infra.ni")

---@alias infra.winsplit.Side 'above'|'below'|'left'|'right'

---split current window, place new window by the 'side' param
---@param side infra.winsplit.Side
---@param name_or_nr? string|integer @bufname or bufnr
return function(side, name_or_nr)
  if name_or_nr == nil then --split current win
    return mi.open_win(0, true, { split = side, win = 0 })
  end

  local host_winid = ni.get_current_win()
  local host_bufnr = ni.win_get_buf(host_winid)

  local bufnr
  if type(name_or_nr) == "number" then
    --split with bufnr
    bufnr = name_or_nr
  else
    --split with bufname
    bufnr = mi.bufnr(name_or_nr, true)
  end

  local enter = true
  local winid = mi.open_win(bufnr, enter, { split = side, win = host_winid })

  if bufnr ~= host_bufnr then
    assert(enter)
    ex("clearjumps")
  end

  return winid
end

