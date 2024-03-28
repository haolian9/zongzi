--
-- for
-- * field: Foo string `json"foo"`
--

local ts = vim.treesitter
local api = vim.api
local jelly = require("infra.jellyfish")("squirrel.docgen.go")
local jumplist = require("infra.jumplist")
local nvimkeys = require("infra.nvimkeys")
local prefer = require("infra.prefer")

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
  local ispcs = api.nvim_buf_call(bufnr, function() return vim.fn.indent(l0 + 1) end)
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
    field_name = ts.get_node_text(name_node, bufnr)
  end

  local r0 = start:start()

  local ann
  do
    local indents = resolve_line_indent(bufnr, r0)
    ann = string.format("%s// %s desc", indents, field_name)
  end

  jumplist.push_here()

  api.nvim_buf_set_lines(bufnr, r0, r0, false, { ann })

  -- search `desc` in generated annotation for easier editing
  do
    api.nvim_win_set_cursor(winid, { r0 + 1, 0 })
    api.nvim_feedkeys(nvimkeys([[V<esc>/\%V\<\zsdesc$<cr>]]), "n", false)
  end
end

---@type fun(start: TSNode, winid: number, bufnr: number): true?[]
local tries = { try_field_ann }

return function()
  local winid = api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(winid)
  local start = nuts.get_node_at_cursor(winid)

  for _, try in ipairs(tries) do
    if try(start, winid, bufnr) then return end
  end
  jelly.warn("not supported node type for generating annotation")
end
