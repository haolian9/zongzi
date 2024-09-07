--
-- for
-- * field: Foo string `json"foo"`
--

local buflines = require("infra.buflines")
local ctx = require("infra.ctx")
local feedkeys = require("infra.feedkeys")
local jelly = require("infra.jellyfish")("squirrel.docgen.go")
local jumplist = require("infra.jumplist")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local wincursor = require("infra.wincursor")

local nuts = require("squirrel.nuts")

---@param start TSNode
---@return TSNode?
local function find_parent_field_decl_node(start)
  ---@type TSNode?
  local node = start
  while node ~= nil do
    if node:type() == "field_declaration" then return node end
    node = node:parent()
  end
end

local function resolve_line_indent(bufnr, l0)
  local ispcs = ctx.buf(bufnr, function() return vim.fn.indent(l0 + 1) end)
  local sw = prefer.bo(bufnr, "shiftwidth")
  return string.rep("\t", ispcs / sw)
end

---@param start TSNode
---@param bufnr number
local function try_field_ann(start, winid, bufnr)
  local field_name
  do
    local decl_node = find_parent_field_decl_node(start)
    if decl_node == nil then return end
    local name_node = decl_node:named_child(0)
    assert(name_node:type() == "field_identifier")
    field_name = nuts.get_1l_node_text(bufnr, name_node)
  end

  local r0 = start:start()

  local ann
  do
    local indents = resolve_line_indent(bufnr, r0)
    ann = string.format("%s// %s desc", indents, field_name)
  end

  jumplist.push_here()

  buflines.prepend(bufnr, r0, ann)

  -- search `desc` in generated annotation for easier editing
  do
    wincursor.go(winid, r0, 0)
    feedkeys([[V<esc>/\%V\<\zsdesc$<cr>]], "n")
  end
end

---@type fun(start: TSNode, winid: number, bufnr: number): true?[]
local tries = { try_field_ann }

return function()
  local winid = ni.get_current_win()
  local bufnr = ni.win_get_buf(winid)
  local start = nuts.get_node_at_cursor(winid)

  for _, try in ipairs(tries) do
    if try(start, winid, bufnr) then return end
  end
  jelly.warn("not supported node type for generating annotation")
end
