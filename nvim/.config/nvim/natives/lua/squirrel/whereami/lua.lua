local ni = require("infra.ni")
local setlib = require("infra.setlib")

local nuts = require("squirrel.nuts")

local collect_stops
do
  local types = setlib.new("function_declaration", "function_definition")
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
  local ntype = node:type()

  if ntype == "function_definition" then return "()" end

  if ntype == "function_declaration" then
    local name = assert(node:named_child(0))
    local t = name:type()
    assert(t == "identifier" or t == "method_index_expression" or t == "dot_index_expression", t)
    return nuts.get_1l_node_text(bufnr, name)
  end

  error("unreachable")
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
  return table.concat(stops, "/")
end
