local ni = require("infra.ni")
local setlib = require("infra.setlib")

local nuts = require("squirrel.nuts")

-- function_definition -> declarator: function_declarator -> declarator: identifier

local collect_stops
do
  local types = setlib.new("function_definition", "declaration")

  ---@param start_node TSNode
  ---@return TSNode[]
  function collect_stops(start_node)
    local stops = {}
    ---@type TSNode?
    local node = start_node
    while node ~= nil do
      local ntype = node:type()
      if types[ntype] then table.insert(stops, 1, node) end
      node = node:parent()
    end
    return stops
  end
end

---@param bufnr integer
---@param node TSNode
---@return string?
local function resolve_stop_name(bufnr, node)
  local ident
  local decls = node:field("declarator")
  while #decls > 0 do
    assert(#decls == 1)
    if decls[1]:type() == "identifier" then
      ident = decls[1]
      break
    end
    decls = decls[1]:field("declarator")
  end
  if ident == nil then return end
  return nuts.get_1l_node_text(bufnr, ident)[1]
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
