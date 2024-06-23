local Ephemeral = require("infra.Ephemeral")
local itertools = require("infra.itertools")
local ni = require("infra.ni")
local rifts = require("infra.rifts")

local nuts = require("squirrel.nuts")
local facts = require("squirrel.whereami.facts")

-- function_definition -> declarator: function_declarator -> declarator: identifier

local collect_stops
do
  local types = itertools.toset({ "function_definition", "declaration" })

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
  return nuts.get_node_lines(bufnr, ident)[1]
end

local function resolve_route(winid)
  local bufnr = ni.win_get_buf(winid)

  local stops = { "" }
  for _, node in ipairs(collect_stops(nuts.get_node_at_cursor(winid))) do
    local stop = resolve_stop_name(bufnr, node)
    if stop ~= nil then table.insert(stops, stop) end
  end

  if #stops == 1 then return end

  return table.concat(stops, "/")
end

do -- main
  local winid = ni.get_current_win()
  print("whereami", resolve_route(winid))
end

return function()
  local route = resolve_route(ni.get_current_win())
  if route == nil then return end

  local bufnr = Ephemeral(nil, { route })

  local winopts = { relative = "cursor", row = -1, col = 0, width = #route, height = 1 }
  local winid = rifts.open.win(bufnr, false, winopts)
  ni.win_set_hl_ns(winid, facts.floatwin_ns)

  vim.defer_fn(function()
    if not ni.win_is_valid(winid) then return end
    ni.win_close(winid, false)
  end, 1000 * 3)
end
