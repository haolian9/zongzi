--about the name, nuts
--* squirrel likes nuts
--* node, utils

local M = {}

local ex = require("infra.ex")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("squirrel.nuts")
local jumplist = require("infra.jumplist")
local ni = require("infra.ni")
local unsafe = require("infra.unsafe")
local wincursor = require("infra.wincursor")
local ts = vim.treesitter

---NB: when the cursor lays at the end of line, it will advance one char
---@param winid number
---@return TSNode
function M.get_node_at_cursor(winid)
  local bufnr = ni.win_get_buf(winid)

  local lnum, col
  do
    lnum, col = wincursor.lc(winid)
    local llen = assert(unsafe.linelen(bufnr, lnum))
    assert(col <= llen, "unreachable: col can not gte llen")
    if col == llen then col = math.max(col - 1, 0) end
  end

  local node = ts.get_node({ bufnr = bufnr, pos = { lnum, col }, ignore_injections = true })
  assert(node, "no tsnode at cursor")

  return node
end

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

---@param a TSNode
---@param b TSNode
---@return boolean
function M.same_range(a, b)
  -- since node:range() returns multiple values rather than a tuple,
  -- the following verbose code helps us to avoid the overhead of creating and looping tables
  local a_r0, a_c0, a_r1, a_c1 = a:range()
  local b_r0, b_c0, b_r1, b_c1 = b:range()
  return a_r0 == b_r0 and a_c0 == b_c0 and a_r1 == b_r1 and a_c1 == b_c1
end

do
  ---@param bufnr integer
  ---@param node TSNode
  ---@return string[]
  function M.get_node_lines(bufnr, node)
    local start_line, start_col, stop_line, stop_col = node:range()

    --stolen from vim.treesitter.get_node_text for edge cases
    if stop_col == 0 then
      if start_line == stop_line then
        start_col = -1
        start_line = start_line - 1
      end
      stop_col = -1
      stop_line = stop_line - 1
    end

    return ni.buf_get_text(bufnr, start_line, start_col, stop_line, stop_col, {})
  end

  ---get the first char from the first line of a node
  ---@param bufnr integer
  ---@param node TSNode
  ---@return string
  function M.get_node_first_char(bufnr, node)
    local start_line, start_col = node:start()
    local text = ni.buf_get_text(bufnr, start_line, start_col, start_line, start_col + 1, {})
    assert(#text == 1)
    local char = text[1]
    assert(#char == 1)
    return char
  end

  ---get the last char from the last line of a node
  ---@param bufnr integer
  ---@param node TSNode
  ---@return string
  function M.get_node_last_char(bufnr, node)
    local stop_line, stop_col = node:end_()
    local text = ni.buf_get_text(bufnr, stop_line, stop_col - 1, stop_line, stop_col, {})
    assert(#text == 1)
    local char = text[1]
    assert(#char == 1)
    return char
  end

  ---get <=n chars from the first line of a node
  ---@param bufnr integer
  ---@param node TSNode
  ---@param n integer
  ---@return string
  function M.get_node_start_chars(bufnr, node, n)
    local start_line, start_col, stop_line, stop_col = node:range()
    local corrected_stop_col
    if start_line == stop_line then
      corrected_stop_col = math.min(start_col + n, stop_col)
    else
      corrected_stop_col = start_col + n
    end
    local text = ni.buf_get_text(bufnr, start_line, start_col, start_line, corrected_stop_col, {})
    assert(#text == 1)
    return text[1]
  end

  ---get <=n chars from the last line of a node
  ---@param bufnr integer
  ---@param node TSNode
  ---@param n integer
  ---@return string
  function M.get_node_end_chars(bufnr, node, n)
    local start_line, start_col, stop_line, stop_col = node:range()
    local corrected_start_col
    if start_line == stop_line then
      corrected_start_col = math.max(stop_col - n, start_col)
    else
      corrected_start_col = math.max(stop_col - n, 0)
    end
    local text = ni.buf_get_text(bufnr, stop_line, corrected_start_col, stop_line, stop_col, {})
    assert(#text == 1)
    return text[1]
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

---assume one buffer has only one tree
---@param bufnr integer
---@param ft? string
---@return TSNode?
function M.get_root_node(bufnr, ft)
  local langtree = ts.get_parser(bufnr, ft)
  local trees = langtree:trees()
  assert(#trees == 1)
  return trees[1]:root()
end

return M
