local M = {}

local buflines = require("infra.buflines")
local feedkeys = require("infra.feedkeys")
local wincursor = require("infra.wincursor")

---insert new line without indents
---cursor follows
function M.insert_newline()
  local winid = ni.get_current_win()
  local bufnr = ni.win_get_buf(winid)
  local lnum = wincursor.lnum(winid)
  buflines.append(bufnr, lnum, "")
  wincursor.go(winid, lnum + 1, 0)
end

function M.esl() feedkeys("<esc>l", "n") end

return M
