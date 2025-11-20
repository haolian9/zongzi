local M = {}

local prefer = require("infra.prefer")

---@param winid integer
---@param ft string
function M.attach(winid, ft)
  local wo = prefer.win(winid)
  wo.foldmethod = "expr"
  wo.foldlevel = 1
  wo.foldexpr = string.format([[v:lua.require'squirrel.folding.exprs'.%s(v:lnum)]], ft)
end

return M
