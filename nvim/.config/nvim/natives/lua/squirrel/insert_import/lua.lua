local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("squirrel.insert_import.lua")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local nuts = require("squirrel.nuts")
local puff = require("puff")

local api = vim.api
local ts = vim.treesitter

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
    local root = assert(ts.get_parser(bufnr):trees()[1]):root()
    for idx in fn.range(root:named_child_count()) do
      local child = root:named_child(idx)
      if is_require_node(child) then return child end
    end
  end

  ---@type TSNode
  local origin = {}
  function origin:start() return -1, 0 end
  function origin:end_() return -1, 0 end
  function origin:range() return -1, 0, -1, 0 end

  ---@return TSNode
  function find_anchor(bufnr) return first_require(bufnr) or origin end
end

local resolve_require_stat
do
  local aliases = {
    ["infra.keymap.buffer"] = "bufmap",
    ["infra.keymap.global"] = "m",
  }

  ---@param line string
  ---@return string?
  local function resolve_as(line)
    local mod = string.match(line, '^require"(.+)"')
    if mod == nil then return end

    local alias = aliases[mod]
    if alias ~= nil then return alias end

    local start = strlib.rfind(mod, ".")
    if start == nil then return mod end

    return string.sub(mod, start + 1)
  end

  ---@param line string
  ---@return string?
  function resolve_require_stat(line)
    local as = resolve_as(line)
    if as == nil then return end
    return string.format("local %s = %s", as, line)
  end
end

return function()
  local host_bufnr = api.nvim_get_current_buf()
  local anchor = find_anchor(host_bufnr)

  puff.input({
    prompt = "require",
    startinsert = true,
    bufcall = function(bufnr)
      --NB: lsp.client.on_attach would change something to the buffer, which conflicts with puff.input
      prefer.bo(bufnr, "filetype", "lua")
      api.nvim_buf_set_lines(bufnr, 0, 1, false, { [[require""]] })
    end,
    wincall = function(winid) api.nvim_win_set_cursor(winid, { 1, #[[require"]] }) end,
  }, function(line)
    if line == nil or line == "" then return end
    local require_stat = resolve_require_stat(line)
    if require_stat == nil then return end

    local anchor_tail = anchor:end_() + 1
    api.nvim_buf_set_lines(host_bufnr, anchor_tail, anchor_tail, false, { require_stat })
    jelly.info("'%s'", require_stat)
  end)
end
