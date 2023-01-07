local ts = vim.treesitter
local api = vim.api
local nuts = require("squirrel.nuts")
local jelly = require("infra.jellyfish")("squirrel.imports", vim.log.levels.INFO)
local nvimkeys = require("infra.nvimkeys")
local ex = require("infra.ex")

---@type { [string]: fun(root: TSNode): TSNode? }
local last_import_finders = {}
do
  last_import_finders.go = function(root)
    local last
    local package_node
    for i = 0, root:named_child_count() - 1 do
      local node = root:named_child(i)
      local itype = node:type()
      jelly.debug("node type=%s", itype)
      if itype == "import_declaration" then
        last = node
      elseif itype == "package_clause" then
        package_node = node
      elseif itype == "comment" then
        -- pass
      else
        break
      end
    end
    -- if there is no import node, then try package_node
    return last or package_node
  end

  last_import_finders.python = function(root)
    local last
    for i = 0, root:named_child_count() - 1 do
      local node = root:named_child(i)
      local itype = node:type()
      jelly.debug("node type=%s", itype)
      if itype == "import_statement" or itype == "import_from_statement" then
        last = node
      elseif itype == "comment" then
        -- pass
      elseif itype == "expression_statement" then
        --- could be docstring
        if node:child(0):type() ~= "string" then break end
      else
        break
      end
    end
    return last
  end
end

local import_prefixes = {
  go = [[import ""<left>]],
  python = [[from ]],
}

return function(win_id)
  win_id = win_id or api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(win_id)

  ---@type TSNode
  local anchor
  local prefix
  do
    ---@type TSNode
    local root
    local lang
    do
      local parser = ts.get_parser(bufnr)
      lang = parser:lang()
      local trees = parser:trees()
      root = trees[1]:root()
      if root == nil then return jelly.warn("no root node found") end
    end

    prefix = import_prefixes[lang]
    if prefix == nil then return jelly.warn("no import prefix for lang %s", lang) end
    local finder = last_import_finders[lang]
    if finder == nil then return jelly.warn("no finder for lang %s", lang) end
    local found = finder(root)
    if found == nil then return jelly.warn("no import node found") end
    anchor = found
  end

  -- locate cursor in a vsplit
  do
    ex("leftabove split")
    local target_win_id = api.nvim_get_current_win()
    nuts.goto_node_end(target_win_id, anchor)
    api.nvim_feedkeys(nvimkeys([[o<cr>]] .. prefix), "ni", false)
  end
end
