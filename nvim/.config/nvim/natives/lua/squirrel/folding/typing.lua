---@diagnostic disable

---@alias squirrel.folding.LineLevel { [integer]: integer }
---@alias squirrel.folding.tree_walker fun(line_level: squirrel.folding.LineLevel, node: TSNode, parent_level: integer)
---@alias squirrel.folding.tip_walker fun(tree_walker: squirrel.folding.tree_walker, line_level: squirrel.folding.LineLevel, tip: TSNode)
---@alias squirrel.folding.fold_expr fun(row: integer): integer
