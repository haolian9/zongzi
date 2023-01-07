-- extends of nvim.treesitter

local M = {}

local api = vim.api
local ts = vim.treesitter
local jelly = require("infra.jellyfish")("squirrel.nuts")
local ex = require("infra.ex")

---@param win_id number
---@return TSNode
function M.get_node_at_cursor(win_id)
  local bufnr = api.nvim_win_get_buf(win_id)
  local cursor = api.nvim_win_get_cursor(win_id)
  return ts.get_node_at_pos(bufnr, cursor[1] - 1, cursor[2], { ignore_injections = true })
end

---@alias squirrel.nuts.goto_node fun(win_id: number, node: TSNode)

---@type squirrel.nuts.goto_node
function M.goto_node_beginning(win_id, node)
  local r0, c0 = node:start()
  api.nvim_win_set_cursor(win_id, { r0 + 1, c0 })
end

---@type squirrel.nuts.goto_node
function M.goto_node_end(win_id, node)
  local r1, c1 = node:end_()
  api.nvim_win_set_cursor(win_id, { r1 + 1, c1 - 1 })
end

--should only to be used for selecting objects
---@param win_id number
---@param node TSNode
---@return boolean
function M.vsel_node(win_id, node)
  local mode = api.nvim_get_mode().mode
  if mode == "no" or mode == "n" then
    -- operator-pending mode
    M.goto_node_beginning(win_id, node)
    ex("normal! v")
    M.goto_node_end(win_id, node)
    return true
  elseif mode == "v" then
    -- visual mode
    M.goto_node_end(win_id, node)
    ex("normal! o")
    M.goto_node_beginning(win_id, node)
    return true
  else
    jelly.err("unexpected mode for vsel_node: %s", mode)
    return false
  end
end

---@param a TSNode
---@param b TSNode
---@return boolean
function M.same_range(a, b)
  local a_r0, a_c0, a_r1, a_c1 = a:range()
  local b_r0, b_c0, b_r1, b_c1 = b:range()
  return a_r0 == b_r0 and a_c0 == b_c0 and a_r1 == b_r1 and a_c1 == b_c1
end

return M
