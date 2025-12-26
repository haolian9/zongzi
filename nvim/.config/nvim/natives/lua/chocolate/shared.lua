local M = {}

local ropes = require("string.buffer")
local new_table = require("table.new")

local ni = require("infra.ni")
local nuts = require("infra.nuts")
local prefer = require("infra.prefer")
local VimRegex = require("infra.VimRegex")

do
  ---@class chocolate.Palette
  ---@field cap integer
  ---@field colors table<integer, true>
  local Impl = {}
  Impl.__index = Impl

  ---@return integer? color
  function Impl:allocate()
    local color, _ = next(self.colors)
    if color == nil then return end
    self.colors[color] = nil
    return color
  end

  ---@param color integer
  function Impl:free(color)
    assert(not self.colors[color])
    self.colors[color] = true
  end

  function Impl:reset()
    for i = 1, self.cap do
      self.colors[i] = true
    end
  end

  ---@param cap integer number of colors
  ---@return chocolate.Palette
  function M.Palette(cap)
    --todo: remove the facts dependency
    local palette = setmetatable({ cap = cap, colors = new_table(0, cap) }, Impl)
    palette:reset()
    return palette
  end
end

do
  local rope = ropes.new(64)

  ---@param keyword string
  ---@return infra.VimRegex
  function M.Regex(keyword)
    rope:put([[\V]])
    if string.find(keyword, "^%a") then rope:put([[\<]]) end
    rope:put(VimRegex.escape_for_verynomagic(keyword))
    if string.find(keyword, "%a$") then rope:put([[\>]]) end
    return VimRegex(rope:get())
  end
end

do
  local ftstops = {
    lua = { function_declaration = true, function_definition = true, do_statement = true, chunk = true },
    python = { function_definition = true },
    zig = { function_declaration = true, struct_declaration = true, test_declaration = true },
    c = { function_definition = true },
    go = { function_declaration = true, function_literal = true },
  }

  ---@param winid integer
  ---@param ng integer
  ---@return TSNode?
  function M.find_stop_node(winid, ng)
    local bufnr = ni.win_get_buf(winid)
    local stops = ftstops[prefer.bo(bufnr, "filetype")]
    if stops == nil then return end
    ---@type TSNode?
    local node = nuts.node_at_cursor(winid)
    while node ~= nil do
      if stops[node:type()] then
        ng = ng - 1
        if ng <= 0 then return node end
      end
      node = node:parent()
    end
  end
end

---@param bufnr integer
---@param ns integer
---@param higroup string
---@param lnum integer
---@param start integer start_col
---@param stop integer stop_col
---@return integer xmid
function M.hi_occurence(bufnr, ns, higroup, lnum, start, stop)
  return ni.buf_set_extmark(bufnr, ns, lnum, start, { --
    end_row = lnum,
    end_col = stop,
    hl_group = higroup,
    invalidate = true,
    undo_restore = false,
    hl_mode = "replace",
  })
end

return M
