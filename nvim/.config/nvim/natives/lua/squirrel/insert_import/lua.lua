local buflines = require("infra.buflines")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("squirrel.insert_import.lua")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local puff = require("puff")
local facts = require("squirrel.insert_import.facts")
local nuts = require("squirrel.nuts")

local find_anchor
do
  ---@param node TSNode
  local function is_require_node(node)
    if node:type() ~= "variable_declaration" then return false end
    local call = nuts.get_named_decendant(node, 0, "assignment_statement", 1, "expression_list", 0, "function_call")
    if call == nil then return false end
    local ident = call:named_child(0)
    if ident == nil then return false end
    if ident:type() ~= "identifier" then return false end
    return true
  end

  ---@param bufnr integer
  ---@return TSNode?
  local function first_require(bufnr)
    local root = assert(nuts.get_root_node(bufnr))

    for idx in itertools.range(root:named_child_count()) do
      local child = root:named_child(idx)
      if is_require_node(child) then return child end
    end
  end

  ---@return TSNode
  function find_anchor(bufnr) return first_require(bufnr) or facts.origin end
end

local resolve_require_stat
do
  local aliases = {
    ["infra.keymap.buffer"] = "bufmap",
    ["infra.keymap.global"] = "m",
    ["infra._strfmt"] = "strfmt",
    ["string.buffer"] = "ropes",
    ["beckon.select"] = "beckon_select",
    ["table.new"] = "new_table",
    ["vim.lsp.util"] = "lsputil",
    ["vim.lsp.protocol"] = "lspro",
  }

  ---@param path string
  ---@return string?
  local function try_alias(path) return aliases[path] end

  ---@param path string
  ---@return string
  local function try_final(path)
    local dot_at = strlib.rfind(path, ".")
    if dot_at == nil then return path end
    return string.sub(path, dot_at + 1)
  end

  ---@param line string
  ---@return string?
  function resolve_require_stat(line)
    local path = string.match(line, '^require"([^"]+)"?$')
    if path == nil then return jelly.warn('no path found in "%s"', line) end

    local as = try_alias(path) or try_final(path)
    assert(as ~= nil)

    return string.format('local %s = require("%s")', as, path)
  end
end

return function()
  local host_bufnr = ni.get_current_buf()
  local anchor = find_anchor(host_bufnr)

  puff.input({
    prompt = "import://lua",
    default = 'require"',
    icon = "🚀",
    startinsert = "a",
    bufcall = function(bufnr) prefer.bo(bufnr, "filetype", "lua") end,
  }, function(line)
    if line == nil or line == "" then return end
    if #line <= #'require"' then return end

    local requires = resolve_require_stat(line)
    if requires == nil then return end

    buflines.append(host_bufnr, anchor:end_(), requires)
    jelly.info("'%s'", requires)
  end)
end
