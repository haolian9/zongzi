local setlib = require("infra.setlib")

local nuts = require("squirrel.nuts")

---@alias Resolver fun(start_node: TSNode): TSNode

local passthrough
do
  local types = setlib.new("comment")
  local function inner(node) return node end

  ---@param ntype string
  ---@return Resolver?
  function passthrough(ntype)
    if types[ntype] then return inner end
  end
end

local seek_upward = (function()
  local stops = setlib.new(
    "function_call",
    "table_constructor",
    "block",
    "field",
    --
    "function_declaration",
    "variable_declaration",
    --
    "function_definition",
    --
    "if_statement",
    "elseif_statement",
    "else_statement",
    "for_statement",
    "return_statement",
    "do_statement",
    --
    "bracket_index_expression",
    "binary_expression",
    "parenthesized_expression",
    "expression_list",
    --
    "for_generic_clause",
    "for_numeric_clause"
  )

  ---@type {[string]: fun(parent: TSNode): boolean}
  local conditional_stops = {
    assignment_statement = function(parent) return not (parent:type() == "variable_declaration") end,
    method_index_expression = function(parent) return not (parent:type() == "function_call") end,
    dot_index_expression = function(parent) return not (parent:type() == "function_call") end,
    ---@diagnostic disable-next-line: unused-local
    break_statement = function(parent_type) return false end,
    ---@diagnostic disable-next-line: unused-local
    variable_list = function(parent_type) return false end,
  }

  ---@return Resolver
  return function(start_node)
    local held = start_node
    while true do
      local held_type = held:type()
      if held_type == "chunk" then break end
      if stops[held_type] then break end
      local parent = held:parent()
      if parent == nil then break end
      local cond = conditional_stops[held_type]
      if cond and cond(parent) then break end
      held = parent
    end
    return held
  end
end)()

return function(winid)
  local node = nuts.get_node_at_cursor(winid)
  local ntype = node:type()
  return (passthrough(ntype) or seek_upward)(node)
end
