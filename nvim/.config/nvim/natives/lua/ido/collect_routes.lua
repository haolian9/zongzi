local fs = require("infra.fs")
local its = require("infra.its")
local prefer = require("infra.prefer")

local nuts = require("squirrel.nuts")

local ts = vim.treesitter

---原则：路径由近到远排序
local collectors = {}

do
  local collectable_anon = {
    do_statement = "do",
    while_statement = "while",
    for_statement = "for",
    if_statement = "if",
    else_statement = "else",
    elseif_statement = "elseif",
    function_definition = "()",
    string = "str",
  }

  local collectable_named = {
    function_declaration = "%s()",
  }

  ---@param bufnr integer
  ---@param start_node TSNode
  function collectors.lua(bufnr, start_node) --
    ---@type TSNode[], string[]
    local parents, names = {}, {}
    do
      local node = start_node
      while true do
        local parent = assert(node:parent())
        node = parent

        local ntype = parent:type()

        if ntype == "chunk" then
          table.insert(parents, 1, parent)
          table.insert(names, 1, "$")
          break
        end

        if collectable_anon[ntype] then
          table.insert(parents, 1, parent)
          table.insert(names, 1, collectable_anon[ntype])
          goto continue
        end

        if collectable_named[ntype] then
          table.insert(parents, 1, parent)
          local fields = parent:field("name")
          assert(#fields == 1)
          local name = nuts.get_1l_node_text(bufnr, fields[1])
          table.insert(names, 1, string.format(collectable_named[ntype], name))
          goto continue
        end

        ::continue::
      end
    end

    ---@type TSNode[], string[]
    local nodes, paths = {}, {}
    for i = 1, #parents do
      local node = parents[i]
      table.insert(nodes, 1, node)

      local path = its(names):head(i):join("/")
      local start_lnum, _, stop_lnum = node:range()
      table.insert(paths, 1, string.format("%d,%d %s", start_lnum, stop_lnum, path))
    end

    return nodes, paths
  end
end

function collectors.final(bufnr, start_node)
  ---@type TSNode[], string[]
  local parents, names = {}, {}
  do
    local root ---@type TSNode
    local node = start_node
    while true do
      local parent = node:parent()
      if parent == nil then break end
      root = parent

      local old_node = node
      node = parent
      if nuts.same_range(parent, old_node) then goto continue end

      local name
      local fields = parent:field("name")
      if #fields == 0 then --anonymous
        name = parent:type()
      else
        assert(#fields == 1)
        name = nuts.get_node_lines(bufnr, fields[1])[1]
      end

      table.insert(parents, 1, parent)
      table.insert(names, 1, name)

      ::continue::
    end
    assert(root ~= nil)
    table.insert(parents, 1, root)
    table.insert(names, 1, "$")
  end

  ---@type TSNode[], string[]
  local nodes, paths = {}, {}
  for i = 1, #parents do
    local node = parents[i]
    table.insert(nodes, 1, node)

    local path = its(names):head(i):join("/")
    local start_lnum, _, stop_lnum = node:range()
    table.insert(paths, 1, string.format("%d,%d %s", start_lnum, stop_lnum, fs.shorten(path)))
  end

  return nodes, paths
end

---@param bufnr integer
---@param cursor infra.wincursor.Position
---@return TSNode[] nodes
---@return string[] paths
return function(bufnr, cursor)
  local start_node = ts.get_node({ bufnr = bufnr, pos = { cursor.lnum, cursor.col }, ignore_injections = true })
  if start_node == nil then error("no tsnode found") end

  local ft = prefer.bo(bufnr, "filetype")
  return (collectors[ft] or collectors.final)(bufnr, start_node)
end
