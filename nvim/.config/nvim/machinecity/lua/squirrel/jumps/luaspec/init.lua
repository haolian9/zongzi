local api = vim.api
local treewalker = require("squirrel.jumps.luaspec.treewalker")
local nodeops = require("squirrel.jumps.luaspec.nodeops")
local jelly = require("infra.jellyfish")("squirrel.jumps.luaspec")
local peerouter = require("squirrel.jumps.luaspec.peerouter")
local nuts = require("squirrel.nuts")
local ex = require("infra.ex")
local nvimkeys = require("infra.nvimkeys")

local M = {
  objects = {},
  motions = {},
  goto_peer = nil,
}

do
  -- expected use in operator-pending, visual mode only
  local function be_normal()
    local mode = api.nvim_get_mode().mode
    if mode == "v" then
      api.nvim_feedkeys(nvimkeys("<esc>"), "n", false)
    elseif mode == "no" then
      api.nvim_feedkeys(nvimkeys("<esc>"), "n", false)
    else
      error("unexpected mode " .. mode)
    end
  end

  ---@param finder fun(start: TSNode) TSNode
  ---@param vseler fun(win_id: number, target: TSNode)
  ---@return fun(win_id: number?)
  local function vsel_object(finder, vseler)
    ---@param win_id number?
    return function(win_id)
      win_id = win_id or api.nvim_get_current_win()
      local target = finder(nuts.get_node_at_cursor(win_id))
      if target == nil then
        jelly.info("no object available")
        be_normal()
        return
      end
      if not vseler(win_id, target) then be_normal() end
    end
  end

  --parent function
  M.objects["if"] = vsel_object(treewalker.find_parent_fn, nodeops.vsel_node_body)
  M.objects["af"] = vsel_object(treewalker.find_parent_fn, nuts.vsel_node)
  --top level function
  M.objects["iF"] = vsel_object(treewalker.find_tip_fn, nodeops.vsel_node_body)
  M.objects["aF"] = vsel_object(treewalker.find_tip_fn, nuts.vsel_node)
  --block
  M.objects["ib"] = vsel_object(treewalker.find_parent_blk, nodeops.vsel_node_body)
  M.objects["ab"] = vsel_object(treewalker.find_parent_blk, nuts.vsel_node)

  M.objects["ie"] = vsel_object(treewalker.find_parent_expr, nuts.vsel_node)
  M.objects["ae"] = M.objects["ie"]
  M.objects["ia"] = vsel_object(treewalker.find_parent_assign, nuts.vsel_node)
  M.objects["aa"] = M.objects["ia"]
  M.objects["ic"] = vsel_object(treewalker.find_parent_call, nuts.vsel_node)
  M.objects["ac"] = M.objects["ic"]
  M.objects["is"] = vsel_object(treewalker.find_parent_state, nuts.vsel_node)
  M.objects["as"] = M.objects["is"]
end

do
  ---@param finder fun(start: TSNode) TSNode
  ---@param go_to fun(win_id: number, target: TSNode)
  ---@return fun(win_id: number?)
  local function goto_object(finder, go_to)
    return function(win_id)
      win_id = win_id or api.nvim_get_current_win()
      local target = finder(nuts.get_node_at_cursor(win_id))
      if target == nil then return jelly.info("no objects available") end
      go_to(win_id, target)
    end
  end

  --beginning of previous/next sibling top level function
  M.motions["[F"] = goto_object(treewalker.find_prev_tip_sibling_fn, nodeops.goto_node_first_identifier)
  M.motions["]F"] = goto_object(treewalker.find_next_tip_sibling_fn, nodeops.goto_node_first_identifier)
  --beginning of previous/next sibling function
  M.motions["[f"] = goto_object(treewalker.find_prev_sibling_fn, nodeops.goto_node_first_identifier)
  M.motions["]f"] = goto_object(treewalker.find_next_sibling_fn, nodeops.goto_node_first_identifier)
  --beginning of previous/next sibling statement
  M.motions["[s"] = goto_object(treewalker.find_prev_sibling_state, nodeops.goto_node_first_identifier)
  M.motions["]s"] = goto_object(treewalker.find_next_sibling_state, nodeops.goto_node_first_identifier)
end

function M.goto_peer(win_id)
  win_id = win_id or api.nvim_get_current_win()
  if not peerouter(win_id) then
    -- fallback to native %
    ex("normal! %")
  end
end

return M
