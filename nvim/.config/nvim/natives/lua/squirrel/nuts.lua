--about the name, nuts
--* squirrel likes nuts
--* node, utils

local M = {}

local buflines = require("infra.buflines")
local ex = require("infra.ex")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("squirrel.nuts")
local jumplist = require("infra.jumplist")
local ni = require("infra.ni")
local infra_nuts = require("infra.nuts")
local wincursor = require("infra.wincursor")

local ts = vim.treesitter

M.get_node_range = infra_nuts.node_range
M.get_node_at_cursor = infra_nuts.node_at_cursor
M.same_range = infra_nuts.same_range
M.get_node_lines = infra_nuts.node_lines
M.get_1l_node_text = infra_nuts.flatnode_text
M.get_root_node = infra_nuts.root_node

do --cursor moving
  ---@alias squirrel.nuts.goto_node fun(winid: number, node: TSNode)

  ---@type squirrel.nuts.goto_node
  function M.goto_node_head(winid, node)
    jumplist.push_here()

    local lnum, col = node:start()
    wincursor.go(winid, lnum, col)
  end

  ---@type squirrel.nuts.goto_node
  function M.goto_node_tail(winid, node)
    jumplist.push_here()

    local lnum, col = node:end_()
    wincursor.go(winid, lnum, col - 1)
  end
end

do --text
  ---get the first char from the first line of a node
  ---@param bufnr integer
  ---@param node TSNode
  ---@return string
  function M.get_node_first_char(bufnr, node)
    local start_line, start_col = node:start()
    local char = buflines.partial_line(bufnr, start_line, start_col, start_col + 1)
    assert(char and #char == 1)
    return char
  end

  ---get the last char from the last line of a node
  ---@param bufnr integer
  ---@param node TSNode
  ---@return string
  function M.get_node_last_char(bufnr, node)
    local _, _, stop_lnum, stop_col = M.get_node_range(node)
    local char = buflines.partial_line(bufnr, stop_lnum, stop_col - 1, stop_col)
    assert(char and #char == 1)
    return char
  end

  ---get <=n chars from the first line of a node
  ---@param bufnr integer
  ---@param node TSNode
  ---@param n integer
  ---@return string
  function M.get_node_start_chars(bufnr, node, n)
    local start_lnum, start_col, stop_lnum, stop_col = M.get_node_range(node)
    local corrected_stop_col
    if start_lnum == stop_lnum then
      if stop_col == -1 then
        corrected_stop_col = start_col + n --this can lead to error()
      else
        corrected_stop_col = math.min(start_col + n, stop_col)
      end
    else
      corrected_stop_col = start_col + n
    end
    return assert(buflines.partial_line(bufnr, start_lnum, start_col, corrected_stop_col))
  end

  ---get <=n chars from the last line of a node
  ---@param bufnr integer
  ---@param node TSNode
  ---@param n integer
  ---@return string
  function M.get_node_end_chars(bufnr, node, n)
    local start_lnum, start_col, stop_lnum, stop_col = M.get_node_range(node)
    local corrected_start_col
    if start_lnum == stop_lnum then
      if stop_col == -1 then
        corrected_start_col = -n
      else
        corrected_start_col = math.max(stop_col - n, start_col)
      end
    else
      corrected_start_col = math.max(stop_col - n, 0)
    end
    return assert(buflines.partial_line(bufnr, stop_lnum, corrected_start_col, stop_col))
  end
end

do --traversal
  --should only to be used for selecting objects
  ---@param winid number
  ---@param node TSNode
  ---@return boolean
  function M.vsel_node(winid, node)
    local mode = ni.get_mode().mode
    if mode == "no" or mode == "n" then
      -- operator-pending mode
      M.goto_node_head(winid, node)
      ex.eval("normal! v")
      M.goto_node_tail(winid, node)
      return true
    elseif mode == "v" then
      -- visual mode
      M.goto_node_tail(winid, node)
      ex.eval("normal! o")
      M.goto_node_head(winid, node)
      return true
    else
      jelly.err("unexpected mode for vsel_node: %s", mode)
      return false
    end
  end
end

---@param root TSNode
---@param ... integer|string @child index, child type
---@return TSNode?
function M.get_named_decendant(root, ...)
  local args = { ... }
  assert(#args % 2 == 0)
  local arg_iter = itertools.iter(args)
  ---@type TSNode
  local next = root
  for i in arg_iter do
    local itype = arg_iter()
    next = next:named_child(i)
    if next == nil then return jelly.debug("n=%d type.expect=%s .actual=%s", i, itype, "nil") end
    if next:type() ~= itype then return jelly.debug("n=%d type.expect=%s .actual=%s", i, itype, next:type()) end
  end
  return next
end

---@param callback fun(trees:table<integer,TSTree>)
function M.on_trees_ready(bufnr, callback)
  local langtree = ts.get_parser(bufnr, nil)
  if langtree == nil then return jelly.warn("no available treesit parser for buf=%s", bufnr) end
  langtree:parse(false, function(err, trees)
    assert(err == nil, err)
    callback(trees)
  end)
end

return M
