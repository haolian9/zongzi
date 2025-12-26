local M = {}

local nuts = require("squirrel.nuts")

---@type squirrel.folding.tip_walker
function M.tip_walker(tree_walker, line_level, tip)
  local start_lnum, _, stop_lnum = nuts.get_node_range(tip)
  local lv = start_lnum ~= stop_lnum and 1 or 0
  line_level[start_lnum] = lv
  line_level[stop_lnum] = lv
  if start_lnum == stop_lnum then return end
  for i = 0, tip:named_child_count() - 1 do
    tree_walker(line_level, assert(tip:named_child(i)), lv)
  end
end

---@type squirrel.folding.tree_walker
function M.tree_walker(line_level, node, parent_level)
  local start_lnum, _, stop_lnum = nuts.get_node_range(node)
  local my_level = parent_level
  if line_level[start_lnum] == nil then
    my_level = parent_level + 1
    line_level[start_lnum] = my_level
  end
  if line_level[stop_lnum] == nil then
    my_level = parent_level + 1
    line_level[stop_lnum] = my_level
  end
  for i = 0, node:named_child_count() - 1 do
    M.tree_walker(line_level, assert(node:named_child(i)), my_level)
  end
end

return M
