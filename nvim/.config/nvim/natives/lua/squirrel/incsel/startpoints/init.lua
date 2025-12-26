local M = {}

local nuts = require("squirrel.nuts")

---@return fun(winid: number): TSNode
function M.n() return nuts.get_node_at_cursor end

---@type {[string]: string} @{filetype: modname}
local known_m
do
  known_m = {}
  for _, ft in ipairs({ "lua" }) do
    known_m[ft] = "squirrel.incsel.startpoints.m_" .. ft
  end
end

---@param filetype string
---@return fun(winid: number): TSNode
function M.m(filetype) return require(assert(known_m[filetype])) end

return M
