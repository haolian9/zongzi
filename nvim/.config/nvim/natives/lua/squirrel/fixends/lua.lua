--supported cases
--* [x] do        -> do | end
--* [x] for..     -> for..do | end
--* [x] for..in.. -> for..do | end
--* [ ] while..   -> while..do | end
--* [x] if..      -> if..then | end
--* [x] if..then  -> if..then | end
--* [x] for..do   -> for..do | end

local jelly = require("infra.jellyfish")("squirrel.fixends", "info")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local resolve_line_indents = require("infra.resolve_line_indents")
local strlib = require("infra.strlib")
local wincursor = require("infra.wincursor")

local nuts = require("squirrel.nuts")

---by search ascendingly
---@param start TSNode
---@return TSNode?
local function find_nearest_error(start)
  ---@type TSNode?
  local node = start
  while true do
    if node == nil then return end
    local ntype = node:type()
    if ntype == "chunk" then return end
    if ntype == "ERROR" then return node end
    node = node:parent()
  end
end

---@param winid integer
---@param bufnr integer
---@param start_node TSNode
---@param err_node TSNode
---@return boolean? @nil=false=failed
local function try_erred_block(winid, bufnr, start_node, err_node)
  local _ = start_node

  local start_chars = nuts.get_node_start_chars(bufnr, err_node, 5)
  local start_line, _, stop_line, stop_col = nuts.get_node_range(err_node)
  local indents, ichar, iunit = resolve_line_indents(bufnr, start_line)

  local fixes, cursor
  if strlib.startswith(start_chars, "if") then
    fixes = { " then", indents .. string.rep(ichar, iunit), indents .. "end" }
    if nuts.get_node_end_chars(bufnr, err_node, #fixes[1]) == fixes[1] then fixes[1] = "" end
    cursor = { lnum = start_line + 1, col = #fixes[2] }
  elseif strlib.startswith(start_chars, "do") then
    fixes = { "", indents .. string.rep(ichar, iunit), indents .. "end" }
    cursor = { lnum = start_line + 1, col = #fixes[2] }
  elseif strlib.startswith(start_chars, "for") or strlib.startswith(start_chars, "while") then
    -- assert(err_node:child():type() == "for")
    fixes = { " do", indents .. string.rep(ichar, iunit), indents .. "end" }
    if nuts.get_node_end_chars(bufnr, err_node, #fixes[1]) == fixes[1] then fixes[1] = "" end
    cursor = { lnum = start_line + 1, col = #fixes[2] }
  else
    return jelly.debug("no available block found")
  end

  ni.buf_set_text(bufnr, stop_line, stop_col, stop_line, stop_col, fixes)
  wincursor.go(winid, cursor.lnum, cursor.col)
  return true
end

---@param winid integer
---@return boolean? @nil=false=failed
return function(winid)
  local bufnr = ni.win_get_buf(winid)
  if prefer.bo(bufnr, "filetype") ~= "lua" then return jelly.warn("only support lua buffer right now") end

  local start_node = nuts.get_node_at_cursor(winid)
  local err_node = find_nearest_error(start_node)
  if err_node == nil then return end

  if try_erred_block(winid, bufnr, start_node, err_node) then return true end
end
