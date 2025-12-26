--lua spec
--* additional body node
--* comment
local M = {}

local nuts = require("squirrel.nuts")

---@type squirrel.folding.tip_walker
function M.tip_walker(tree_walker, line_level, tip)
  local start_lnum, _, stop_lnum = nuts.get_node_range(tip)

  if tip:type() == "comment" then
    for lnum = start_lnum, stop_lnum do
      if line_level[lnum] ~= nil then
        --inline comment
      else
        line_level[lnum] = 2
      end
    end
    return
  end

  local lv = 1
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

  local ntype = node:type()

  assert(ntype ~= "comment_content")
  --stop walking, comments have no child
  if ntype == "comment" then
    if line_level[start_lnum] then return end
    local lv = parent_level + 2
    for lnum = start_lnum, stop_lnum do
      assert(line_level[lnum] == nil, lnum)
      line_level[lnum] = lv
    end
    return
  end

  local inc = 0
  if ntype ~= "block" then
    if line_level[start_lnum] == nil then
      inc = 1
      line_level[start_lnum] = parent_level + inc
    end
    if line_level[stop_lnum] == nil then
      inc = 1
      line_level[stop_lnum] = parent_level + inc
    end
  end

  for i = 0, node:named_child_count() - 1 do
    M.tree_walker(line_level, assert(node:named_child(i)), parent_level + inc)
  end
end

return M
