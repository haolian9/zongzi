local M = {}

local ex = require("infra.ex")
local feedkeys = require("infra.feedkeys")
local jelly = require("infra.jellyfish")("squirrel.jumps.luaspec")
local mi = require("infra.mi")
local ni = require("infra.ni")

local nodeops = require("squirrel.jumps.luaspec.nodeops")
local peerouter = require("squirrel.jumps.luaspec.peerouter")
local treewalker = require("squirrel.jumps.luaspec.treewalker")
local nuts = require("squirrel.nuts")

M.objects = {}
M.motions = {}
M.goto_peer = nil

do
  -- expected use in operator-pending, visual mode only
  local function be_normal()
    local mode = ni.get_mode().mode
    if mode == "v" then
      feedkeys("<esc>", "n")
    elseif mode == "no" then
      feedkeys("<esc>", "n")
    else
      error("unexpected mode " .. mode)
    end
  end

  ---@param finder fun(start: TSNode) TSNode
  ---@param vseler fun(winid: number, target: TSNode)
  ---@return fun(winid: number?)
  local function vsel_object(finder, vseler)
    ---@param winid number?
    return function(winid)
      winid = mi.resolve_winid_param(winid)
      local target = finder(nuts.get_node_at_cursor(winid))
      if target == nil then
        jelly.info("no object available")
        be_normal()
        return
      end
      if not vseler(winid, target) then be_normal() end
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
  M.objects["is"] = vsel_object(treewalker.find_parent_stm, nuts.vsel_node)
  M.objects["as"] = M.objects["is"]
end

do
  ---@param finder fun(start: TSNode) TSNode
  ---@param go_to fun(winid: number, target: TSNode)
  ---@return fun(winid: number?)
  local function goto_object(finder, go_to)
    return function(winid)
      winid = mi.resolve_winid_param(winid)
      for _ = 1, vim.v.count1 do
        local target = finder(nuts.get_node_at_cursor(winid))
        if target == nil then return jelly.info("no objects available") end
        go_to(winid, target)
      end
    end
  end

  --beginning of previous/next sibling top level function
  M.motions["[F"] = goto_object(treewalker.find_prev_tip_sibling_fn, nodeops.goto_node_first_identifier)
  M.motions["]F"] = goto_object(treewalker.find_next_tip_sibling_fn, nodeops.goto_node_first_identifier)
  --beginning of previous/next sibling function
  M.motions["[f"] = goto_object(treewalker.find_prev_sibling_fn, nodeops.goto_node_first_identifier)
  M.motions["]f"] = goto_object(treewalker.find_next_sibling_fn, nodeops.goto_node_first_identifier)
  --beginning of previous/next sibling statement
  M.motions["[s"] = goto_object(treewalker.find_prev_sibling_stm, nodeops.goto_node_first_identifier)
  M.motions["]s"] = goto_object(treewalker.find_next_sibling_stm, nodeops.goto_node_first_identifier)
  --beginning/ending of the current function
  M.motions["<f"] = goto_object(treewalker.find_parent_fn, nodeops.goto_node_first_identifier)
  M.motions[">f"] = goto_object(treewalker.find_parent_fn, nuts.goto_node_tail)
end

function M.goto_peer(winid)
  winid = mi.resolve_winid_param(winid)
  if not peerouter(winid) then
    -- fallback to native %
    ex.eval("normal! %")
  end
end

return M
