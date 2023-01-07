local api = vim.api
local nuts = require("squirrel.nuts")
local treewalker = require("squirrel.jumps.zigspec.treewalker")
local nodeops = require("squirrel.jumps.zigspec.nodeops")
local jelly = require("infra.jellyfish")("squirrel.jumps.zigspec")

local M = {
  objects = {},
  motions = {},
  -- not available, treesitter-zig generates nonsense ast
  goto_peer = nil,
}

do
  ---@param finder fun(start: TSNode) TSNode
  ---@param vseler fun(win_id: number, target: TSNode)
  ---@return fun(win_id: number?)
  local function vsel_object(finder, vseler)
    ---@param win_id number?
    return function(win_id)
      win_id = win_id or api.nvim_get_current_win()
      local target = finder(nuts.get_node_at_cursor(win_id))
      if target == nil then return jelly.info("no objects available") end
      vseler(win_id, target)
    end
  end

  --parent function
  M.objects['if'] = vsel_object(treewalker.find_tip_fn, nodeops.vsel_node_body)
  M.objects.af = vsel_object(treewalker.find_tip_fn, nodeops.vsel_node)

  --function call
  M.objects["ic"] = vsel_object(treewalker.find_parent_call, nodeops.vsel_node)
  M.objects["ac"] = vsel_object(treewalker.find_parent_call, nodeops.vsel_node)
end

do
  ---@param finder fun(start: TSNode) TSNode
  ---@param gotoer fun(win_id: number, target: TSNode)
  ---@return fun(win_id: number?)
  local function goto_object(finder, gotoer)
    return function(win_id)
      win_id = win_id or api.nvim_get_current_win()
      local target = finder(nuts.get_node_at_cursor(win_id))
      if target == nil then return jelly.info("no objects available") end
      gotoer(win_id, target)
    end
  end

  --beginning of previous/next sibling top level function
  M.motions["[f"] = goto_object(treewalker.find_prev_tip_sibling_fn, nodeops.goto_node_beginning)
  M.motions["]f"] = goto_object(treewalker.find_next_tip_sibling_fn, nodeops.goto_node_beginning)
end

return M
