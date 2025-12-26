-- tip: first generation nodes
-- block: nodes have a body
-- expr: nodes consist of a expr

local M = {}

---@param ... string
---@return fun(itype: string): boolean
local function type_checker(...)
  local types = {}
  for _, t in ipairs({ ... }) do
    types[t] = true
  end
  return function(itype) return types[itype] == true end
end

local is_fn_node = type_checker("function_declaration", "function_definition")
-- stylua: ignore
local is_blk_node = type_checker(unpack{
  "do_statement", "while_statement", "for_statement", "if_statement", "else_statement",
  "elseif_statement",
})
local is_expr_node = type_checker("expression_list", "binary_expression", "unary_expression")
local is_assign_node = type_checker("assignment_statement", "variable_declaration")
local is_call_node = type_checker("function_call")
-- stylua: ignore
local is_state_node = type_checker(unpack{
  "assignment_statement", "variable_declaration", "return_statement", "function_call", "if_statement",
  "function_declaration", "do_statement",
})

do
  ---@param test fun(itype: string)
  local function find_parent_by(test)
    ---@param start TSNode
    ---@return TSNode?
    return function(start)
      ---@type TSNode?
      local node = start
      while node ~= nil do
        if test(node:type()) then return node end
        node = node:parent()
      end
    end
  end

  M.find_parent_fn = find_parent_by(is_fn_node)
  M.find_parent_blk = find_parent_by(is_blk_node)
  M.find_parent_expr = find_parent_by(is_expr_node)
  M.find_parent_assign = find_parent_by(is_assign_node)
  M.find_parent_call = find_parent_by(is_call_node)
  M.find_parent_stm = find_parent_by(is_state_node)
end

---@param start TSNode
---@return TSNode?
function M.find_tip(start)
  ---@type TSNode?
  local node = start
  local tip
  while node ~= nil do
    local parent = node:parent()
    if parent == nil then break end
    tip = node
    node = parent
  end
  return tip
end

---@param start TSNode
---@return TSNode?
function M.find_tip_fn(start)
  ---@type TSNode?
  local node = start
  local tip
  while node ~= nil do
    if is_fn_node(node:type()) then tip = node end
    node = node:parent()
  end
  return tip
end

do
  ---@param find_parent fun(start: TSNode) TSNode?
  ---@param prev_or_next "next_sibling"|"prev_sibling"
  ---@param test fun(itype: string) boolean
  local function find_sibling_by(find_parent, prev_or_next, test)
    ---@param start TSNode
    ---@return TSNode?
    return function(start)
      local parent = find_parent(start)
      if parent == nil then return end
      local node = parent[prev_or_next](parent)
      while node ~= nil do
        if test(node:type()) then return node end
        node = node[prev_or_next](node)
      end
    end
  end

  M.find_next_sibling_fn = find_sibling_by(M.find_parent_fn, "next_sibling", is_fn_node)
  M.find_prev_sibling_fn = find_sibling_by(M.find_parent_fn, "prev_sibling", is_fn_node)
  M.find_prev_tip_sibling_fn = find_sibling_by(M.find_tip, "prev_sibling", is_fn_node)
  M.find_next_tip_sibling_fn = find_sibling_by(M.find_tip, "next_sibling", is_fn_node)
  M.find_next_sibling_stm = find_sibling_by(M.find_parent_stm, "next_sibling", is_state_node)
  M.find_prev_sibling_stm = find_sibling_by(M.find_parent_stm, "prev_sibling", is_state_node)
end

return M
