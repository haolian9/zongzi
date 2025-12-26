local oop = require("infra.oop")

local nuts = require("squirrel.nuts")

local resolvers = oop.lazyattrs({}, function(ft)
  local modname = string.format("squirrel.folding.Resolver.%s", ft)
  return require(modname)
end)

local tips = {
  --stylua: ignore start
  zig    = "zig",
  go     = "zig",
  json   = "zig",
  c      = "c",
  glsl   = "c",
  lua    = "lua",
  python = "python",
  --stylua: ignore end
}

local trees = {
  --stylua: ignore start
  zig    = "zig",
  go     = "zig",
  json   = "zig",
  c      = "c",
  glsl   = "c",
  lua    = "lua",
  python = "python",
  --stylua: ignore end
}

---@return squirrel.folding.tip_walker
local function get_tip_walker(ft)
  ft = assert(tips[ft], ft)
  return resolvers[ft].tip_walker
end

---@return squirrel.folding.tree_walker
local function get_tree_walker(ft)
  ft = assert(trees[ft], ft)
  return resolvers[ft].tree_walker
end

--:h fold-expr
---@param ft string
---@return fun(bufnr: number): squirrel.folding.LineLevel?
return function(ft)
  local walk_tip = get_tip_walker(ft)
  local walk_tree = get_tree_walker(ft)

  return function(bufnr)
    local root = nuts.get_root_node(bufnr, ft)
    if root == nil then return end
    ---@type squirrel.folding.LineLevel
    local line_level = {}
    for i = 0, root:named_child_count() - 1 do
      walk_tip(walk_tree, line_level, assert(root:named_child(i)))
    end
    return line_level
  end
end
