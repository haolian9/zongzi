local itertools = require("infra.itertools")
local ni = require("infra.ni")

local nuts = require("squirrel.nuts")

local collect_stops
do
  local types = itertools.toset({ "function_declaration", "function_definition" })
  ---collect 'stop's from inner to outer
  ---@param start_node TSNode
  ---@return TSNode[]
  function collect_stops(start_node)
    local stacks = {}
    ---@type TSNode?
    local node = start_node
    while node ~= nil do
      local ntype = node:type()
      if ntype == "chunk" then break end
      if types[ntype] then table.insert(stacks, 1, node) end
      node = node:parent()
    end
    return stacks
  end
end

---@param bufnr integer
---@param node TSNode
---@return string?
local function resolve_stop_name(bufnr, node)
  local fields = node:field("name")
  if #fields == 0 then return "()" end
  if #fields == 1 then
    local name = fields[1]
    local ntype = name:type()
    assert(ntype == "identifier" or ntype == "method_index_expression" or ntype == "dot_index_expression", ntype)
    return nuts.get_node_lines(bufnr, name)[1]
  end
  error("unreachable: multiple name field")
end

---@param winid integer
---@return string
return function(winid)
  local bufnr = ni.win_get_buf(winid)

  local stops = { "" }
  for _, node in ipairs(collect_stops(nuts.get_node_at_cursor(winid))) do
    local stop = resolve_stop_name(bufnr, node)
    if stop ~= nil then table.insert(stops, stop) end
  end
  if #stops == 1 then return "/" end
  return table.concat(stops, "/")
end
