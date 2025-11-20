local fs = require("infra.fs")
local its = require("infra.its")
local nuts = require("infra.nuts")
local prefer = require("infra.prefer")

local ts = vim.treesitter

---@param root_type string
---@param anons {[string]:string} @{node-type: repr}
---@param nameds {[string]:string} @{node-type: repr}
local function LangCollector(root_type, anons, nameds)
  ---@param bufnr integer
  ---@param start_node TSNode
  return function(bufnr, start_node)
    ---@type TSNode[], string[]
    local parents, names = {}, {}
    do
      local node = start_node
      while true do
        local parent = assert(node:parent(), node:sexpr())
        node = parent

        local ntype = parent:type()

        if ntype == root_type then
          table.insert(parents, 1, parent)
          table.insert(names, 1, "$")
          break
        end

        if anons[ntype] then
          table.insert(parents, 1, parent)
          table.insert(names, 1, anons[ntype])
          goto continue
        end

        if nameds[ntype] then
          table.insert(parents, 1, parent)
          local fields = parent:field("name")
          assert(#fields == 1)
          local name = nuts.flatnode_text(bufnr, fields[1])
          table.insert(names, 1, string.format(nameds[ntype], name))
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

---原则：路径由近到远排序
local collectors = {}

collectors.lua = LangCollector( --
  "chunk",
  {
    do_statement = "do",
    while_statement = "while",
    for_statement = "for",
    if_statement = "if",
    else_statement = "else",
    elseif_statement = "elseif",
    function_definition = "()",
    string = "str",
  },
  {
    function_declaration = "%s()",
  }
)

collectors.python = LangCollector( --
  "module",
  {
    while_statement = "while",
    for_statement = "for",
    with_statement = "with",
    --
    if_statement = "if",
    elif_clause = "elif",
    --
    decorated_definition = "@()",
    lambda = "()",
    dictionary = "{}",
    list = "[]",
    set = "[]",
    --
    try_clause = "try",
    except_clause = "except",
    finally_clause = "final",
    --
    else_clause = "else",
    block = "blk",
    string = "str",
  },
  {
    function_definition = "%s()",
    class_definition = "%s::",
  }
)

collectors.zig = LangCollector( --
  "source_file",
  {
    Decl = "decl",
    Statement = "stm",
    SuffixExpr = "blk",
    --
    SwitchExpr = "swit",
    SwitchProng = "case",
    --
    WhileStatement = "while",
    ForStatement = "for",
    IfStatement = "if",
    --
    ContainerDecl = "struct",
    --
    Block = "blk",
  },
  {}
)

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
        name = nuts.node_lines(bufnr, fields[1])[1]
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
