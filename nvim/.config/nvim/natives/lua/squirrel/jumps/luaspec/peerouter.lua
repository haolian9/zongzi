--design choices
--* start node must be a if/else/elseif/while/for
--* it's pointless to move to the then, do node
--
--uncovered cases:
--* expr: x and y or z

---@alias squirrel.jumps.goto_peer fun(winid: number, node: TSNode, itype: string)

local nuts = require("squirrel.nuts")

local is_cond_node = (function()
  local types = {
    if_statement = true,
    else_statement = true,
    elseif_statement = true,
  }
  ---@param itype string
  ---@return boolean
  return function(itype) return types[itype] == true end
end)()

local function at_node_end() return vim.fn.expand("<cword>") == "end" end

---@type squirrel.jumps.goto_peer
local function goto_cond_peer(winid, node, itype)
  if itype == "if_statement" then
    if at_node_end() then return nuts.goto_node_head(winid, node) end
    for i = 0, node:named_child_count() - 1 do
      local child = node:named_child(i)
      if is_cond_node(child:type()) then return nuts.goto_node_head(winid, child) end
    end
    return nuts.goto_node_tail(winid, node)
  end

  if itype == "elseif_statement" then
    local sib = node:next_named_sibling()
    while sib ~= nil do
      if is_cond_node(sib:type()) then return nuts.goto_node_head(winid, sib) end
      sib = sib:next_named_sibling()
    end
    return nuts.goto_node_tail(winid, assert(node:parent()))
  end

  if itype == "else_statement" then return nuts.goto_node_tail(winid, assert(node:parent())) end

  error("unreachable: unexpected itype=" .. itype)
end

---@type squirrel.jumps.goto_peer
local function goto_blk_peer(winid, node, itype)
  local _ = itype
  if at_node_end() then return nuts.goto_node_head(winid, node) end
  nuts.goto_node_tail(winid, node)
end

local routes = {
  -- condition
  if_statement = goto_cond_peer,
  else_statement = goto_cond_peer,
  elseif_statement = goto_cond_peer,
  -- block
  do_statement = goto_blk_peer,
  function_declaration = goto_blk_peer,
  function_definition = goto_blk_peer,
  -- loop
  for_statement = goto_blk_peer,
  while_statement = goto_blk_peer,
}

---@param winid number
---@return boolean
return function(winid)
  local start = nuts.get_node_at_cursor(winid)
  local itype = start:type()
  local route = routes[itype]
  if route then route(winid, start, itype) end
  return route ~= nil
end
