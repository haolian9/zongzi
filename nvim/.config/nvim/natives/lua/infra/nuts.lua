--about the name:
--* extracted from squirrel
--* squirrel likes nuts
--* node, utils

local M = {}

local buflines = require("infra.buflines")
local mi = require("infra.mi")
local ni = require("infra.ni")
local unsafe = require("infra.unsafe")
local wincursor = require("infra.wincursor")
local ts = vim.treesitter

do --range
  ---the TSNode:range() could return illegal range, especially the root node
  ---@param node TSNode
  ---@return integer start_lnum @0-based, inclusive
  ---@return integer start_col @0-based, inclusive
  ---@return integer stop_lnum @0-based, inclusive
  ---@return integer stop_col @0-based, exclusive; can be -1 which indicates EOL
  function M.node_range(node)
    local start_lnum, start_col, stop_lnum, stop_col = node:range()

    --stolen from vim.treesitter.get_node_text for edge cases
    if stop_col == 0 then
      if start_lnum == stop_lnum then
        start_col = -1
        start_lnum = start_lnum - 1
      end
      stop_col = -1
      stop_lnum = stop_lnum - 1
    end

    return start_lnum, start_col, stop_lnum, stop_col
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
end

do --node
  ---assume one buffer has only one tree
  ---@param bufnr integer
  ---@param ft? string
  ---@return TSNode?
  function M.root_node(bufnr, ft)
    local langtree = assert(ts.get_parser(bufnr, ft), "no available treesit parser")
    ---to ensure sync :parse()
    local trees = langtree:parse()
    if #trees == 0 then return end
    assert(#trees == 1, #trees)
    return trees[1]:root()
  end

  ---NB: when the cursor lays at the end of line, it will advance one char
  ---@param winid? integer
  ---@return TSNode
  function M.node_at_cursor(winid)
    winid = mi.resolve_winid_param(winid)
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
end

do --node text
  ---@param bufnr integer
  ---@param node TSNode
  ---@return string[]
  function M.node_lines(bufnr, node)
    local start_lnum, start_col, stop_lnum, stop_col = M.node_range(node)
    return ni.buf_get_text(bufnr, start_lnum, start_col, stop_lnum, stop_col, {})
  end

  ---ensure the given node is 1-line-range
  ---returned string will never contain '\n'
  ---@param bufnr integer
  ---@param node TSNode
  ---@return string
  function M.flatnode_text(bufnr, node)
    local start_line, start_col, stop_line, stop_col = M.node_range(node)
    assert(start_line == stop_line, "not 1-line-range node")
    return assert(buflines.partial_line(bufnr, start_line, start_col, stop_col))
  end
end

return M

