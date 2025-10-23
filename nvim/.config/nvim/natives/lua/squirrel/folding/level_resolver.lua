local nuts = require("squirrel.nuts")
--[[
python spec
* additional body node
* no closing row

lua spec
* additional body node

c spec
* inline vs newline {
--]]

---@type squirrel.folding.TreeWalkers
local tree_walkers = {}
do
  function tree_walkers:lua(line_level, node, parent_level)
    local start_lnum, _, stop_lnum = nuts.get_node_range(node)
    local my_level = parent_level
    if node:type() ~= "block" then
      if line_level[start_lnum] == nil then
        my_level = parent_level + 1
        line_level[start_lnum] = my_level
      end
      if line_level[stop_lnum] == nil then
        my_level = parent_level + 1
        line_level[stop_lnum] = my_level
      end
    end
    for i = 0, node:named_child_count() - 1 do
      self:lua(line_level, node:named_child(i), my_level)
    end
  end

  function tree_walkers:zig(line_level, node, parent_level)
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
      self:zig(line_level, node:named_child(i), my_level)
    end
  end

  function tree_walkers:python(line_level, node, parent_level)
    local start_lnum = node:start()
    local my_level = parent_level
    if node:type() ~= "block" then
      if line_level[start_lnum] == nil then
        my_level = parent_level + 1
        line_level[start_lnum] = my_level
      end
    end
    for i = 0, node:named_child_count() - 1 do
      self:python(line_level, node:named_child(i), my_level)
    end
  end

  function tree_walkers:c(line_level, node, parent_level)
    local start_lnum, _, stop_lnum = nuts.get_node_range(node)
    local my_level = parent_level
    if node:type() ~= "block" then
      if line_level[start_lnum] == nil then
        my_level = parent_level + 1
        line_level[start_lnum] = my_level
      end
      if line_level[stop_lnum] == nil then
        my_level = parent_level + 1
        line_level[stop_lnum] = my_level
      end
    end
    for i = 0, node:named_child_count() - 1 do
      self:c(line_level, node:named_child(i), my_level)
    end
  end

  tree_walkers.go = tree_walkers.zig
  tree_walkers.json = tree_walkers.zig
end

---@type squirrel.folding.TipWalkers
local tip_walkers = {}
do
  function tip_walkers:zig(tree_walker, line_level, tip)
    local start_lnum, _, stop_lnum = nuts.get_node_range(tip)
    local lv = start_lnum ~= stop_lnum and 1 or 0
    line_level[start_lnum] = lv
    line_level[stop_lnum] = lv
    if start_lnum == stop_lnum then return end
    for i = 0, tip:named_child_count() - 1 do
      tree_walker(tree_walkers, line_level, tip:named_child(i), lv)
    end
  end

  function tip_walkers:python(tree_walker, line_level, tip)
    local start_lnum, _, stop_lnum = nuts.get_node_range(tip)
    local lv = start_lnum ~= stop_lnum and 1 or 0
    line_level[start_lnum] = lv
    if start_lnum == stop_lnum then return end
    for i = 0, tip:named_child_count() - 1 do
      tree_walker(tree_walkers, line_level, tip:named_child(i), lv)
    end
  end

  tip_walkers.lua = tip_walkers.zig
  tip_walkers.go = tip_walkers.zig
  tip_walkers.c = tip_walkers.zig
  tip_walkers.json = tip_walkers.zig
end

--:h fold-expr
---@param ft string
---@return fun(bufnr: number): squirrel.folding.LineLevel
return function(ft)
  local walk_tip = assert(tip_walkers[ft], "unsupported tip_walker for ft=")
  local walk_tree = assert(tree_walkers[ft], "unsupported tree_walker for ft=")

  return function(bufnr)
    ---@type TSNode
    local root = assert(nuts.get_root_node(bufnr))

    ---@type squirrel.folding.LineLevel
    local line_level = {}

    for i = 0, root:named_child_count() - 1 do
      walk_tip(tip_walkers, walk_tree, line_level, root:named_child(i))
    end

    return line_level
  end
end
