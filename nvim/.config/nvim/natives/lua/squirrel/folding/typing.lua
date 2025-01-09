---@diagnostic disable

---@alias squirrel.folding.LineLevel { [number]: number }
---@alias squirrel.folding.tree_walker fun(self: squirrel.folding.TreeWalkers, line_level: squirrel.folding.LineLevel, node: TSNode, parent_level: number)
---@alias squirrel.folding.TreeWalkers { [string]: squirrel.folding.tree_walker }
---@alias squirrel.folding.tip_walker fun(self: squirrel.folding.TipWalkers, tree_walker: squirrel.folding.tree_walker, line_level: squirrel.folding.LineLevel, tip: TSNode)
---@alias squirrel.folding.TipWalkers { [string]: squirrel.folding.tip_walker }
---@alias squirrel.folding.fold_expr fun(lnum: number): number
