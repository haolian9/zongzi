--
-- annotation flavor: * https://github.com/sumneko/lua-language-server/wiki/Annotations
--
-- generate documents for
-- * annotations of function signature
--

local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("squirrel.docgen", "INFO")
local ni = require("infra.ni")
local resolve_line_indents = require("infra.resolve_line_indents")

local parrot = require("parrot")
local nuts = require("squirrel.nuts")

local function find_fn_node_around_cursor(winid)
  local start = nuts.get_node_at_cursor(winid)

  ---@type TSNode?
  local node = start
  while node ~= nil do
    local itype = node:type()
    if itype == "function_declaration" or itype == "function_definition" then return node end
    node = node:parent()
  end
end

---@param fn_node TSNode
---@return TSNode?
local function find_params_node(fn_node)
  if fn_node:type() == "function_declaration" then
    return assert(fn_node:named_child(1))
  elseif fn_node:type() == "function_definition" then
    return assert(fn_node:named_child(0))
  else
    return jelly.fatal("unreachable", "unable to find params child node: %s", fn_node:sexpr())
  end
end

---@param fn_node TSNode
---@return string?
local function resolve_return_type(fn_node)
  local body_node = fn_node:field("body")[1]
  if body_node == nil then return end
  local return_nil = false
  local return_any = false
  ---@type TSNode[]
  local stack = { body_node }
  while #stack > 0 do
    ---@type TSNode
    local node = table.remove(stack, 1)
    local itype = node:type()
    if not (itype == "function_declaration" or itype == "function_definition") then
      if itype == "return_statement" then
        -- only itself
        if node:child_count() == 1 then
          return_nil = true
        else
          return_any = true
        end
      else
        for child in node:iter_children() do
          table.insert(stack, child)
        end
      end
    end
  end

  if return_any then return return_nil and "${1:any}?" or "${1:any}" end
end

return function()
  local winid = ni.get_current_win()
  local bufnr = ni.win_get_buf(winid)

  local fn_node = find_fn_node_around_cursor(winid)
  if fn_node == nil then return end
  local params_node = assert(find_params_node(fn_node))

  local anns = {}
  do
    for i in itertools.range(params_node:named_child_count()) do
      local node = params_node:named_child(i)
      local text = nuts.get_1l_node_text(bufnr, node)
      table.insert(anns, string.format("---@param %s $1", text))
    end
    local return_type = resolve_return_type(fn_node)
    if return_type then table.insert(anns, string.format("---@return %s", return_type)) end
    if #anns == 0 then return jelly.info("no param nor return") end
    table.insert(anns, "")
  end

  do
    local lnum = fn_node:start()
    local indents = resolve_line_indents(bufnr, lnum)
    local col = #indents
    parrot.external_expand(anns, winid, { lnum = lnum, col = col, col_end = col })
  end
end
