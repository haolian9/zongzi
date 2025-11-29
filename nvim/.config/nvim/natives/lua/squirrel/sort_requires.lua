---design choices/limits:
---* only for lua
---* only top level `local x = require'x'`
---* no gap lines between require statements, otherwise the later will be ignored
---* supported forms
---  * `local x = require'x'`
---  * `local x = require'x'('x')('y')...`
---* not supported forms
---  * `local x, y = require'x', require'y'`
---  * `local x = require'x' ---x`
---  * `     local x = require'x'     `
---  * `local x = require('x' .. 'y')`
---  * `local x = require(string.format('x.%s', 'y'))`
---* sort in alphabet order, based on the 'tier' of each require statement
---
---require tiers:
---  * builtin: ffi, math
---  * vim's: require'vim.lsp.protocol'
---  * hal's: infra ...
---  * others: ...
---

local buflines = require("infra.buflines")
local BufTickRegulator = require("infra.BufTickRegulator")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("squirrel.sort_requires")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local setlib = require("infra.setlib")
local strlib = require("infra.strlib")

local nuts = require("squirrel.nuts")

---@alias Require {name: string, node: TSNode}

---@param bufnr integer
---@param root TSNode
---@return string?
local function find_require_mod_name(bufnr, root)
  if root:type() ~= "variable_declaration" then return end

  local expr_list = nuts.get_named_decendant(root, 0, "assignment_statement", 1, "expression_list")
  if expr_list == nil then return end

  ---@type TSNode
  local ident
  do
    ---`local x = require'x'`
    ---`local x = require'x'('x')('y')('z')`
    local fn_call = nuts.get_named_decendant(expr_list, 0, "function_call")
    if fn_call == nil then return end
    for _ = 1, 5 do
      local child = fn_call:named_child(0)
      if child == nil then return end
      if child:type() == "identifier" then
        ident = child
        break
      end
      if child:type() ~= "function_call" then return end
      fn_call = child
    end
    if ident == nil then return jelly.err("too many nested function calls on the RHS") end
  end

  if nuts.get_1l_node_text(bufnr, ident) ~= "require" then return end

  local arg0
  do
    local args = ident:next_sibling()
    assert(args ~= nil and args:type() == "arguments")
    arg0 = args:named_child(0)
    assert(arg0 ~= nil and arg0:type() == "string")
  end

  local name
  do
    name = nuts.get_1l_node_text(bufnr, arg0)
    if strlib.startswith(name, '"') or strlib.startswith(name, "'") then
      name = string.sub(name, 2, -2)
    elseif strlib.startswith(name, "[[") then
      name = string.sub(name, 3, -3)
    else
      error("unknown chars surrounds the string")
    end
  end

  return name
end

local sorted_tiers
do
  local preset_tiers = {
    setlib.new("ffi", "string", "jit", "table"),
    setlib.new("vim"),
    setlib.new("infra", "cthulhu"),
  }

  ---@param a Require
  ---@param b Require
  ---@return boolean
  local function compare_requires(a, b) return string.lower(a.name) < string.lower(b.name) end

  ---@param orig_requires Require[]
  ---@return Require[][]
  function sorted_tiers(orig_requires)
    local tiers = {}
    do
      for i = 1, #preset_tiers + 1 do
        tiers[i] = {}
      end
      for _, el in ipairs(orig_requires) do
        local tier_ix
        local prefix = strlib.iter_splits(el.name, ".")()
        for i, presets in ipairs(preset_tiers) do
          if presets[prefix] then
            tier_ix = i
            break
          end
        end
        if tier_ix == nil then tier_ix = #tiers end
        table.insert(tiers[tier_ix], el)
      end
    end

    for _, requires in ipairs(tiers) do
      table.sort(requires, compare_requires)
    end

    return tiers
  end
end

local regulator = BufTickRegulator(1024)

return function(bufnr)
  if bufnr == nil or bufnr == 0 then bufnr = ni.get_current_buf() end
  if prefer.bo(bufnr, "filetype") ~= "lua" then return jelly.err("only support lua buffer") end

  if regulator:throttled(bufnr) then return jelly.debug("no change") end

  ---for latter returns without any changes
  regulator:update(bufnr)

  local root = assert(nuts.get_root_node(bufnr))

  local start_line, stop_line, tiers
  do
    ---@type Require[]
    local requires = {}
    do
      local section_started = false
      for i in itertools.range(root:named_child_count()) do
        local node = assert(root:named_child(i), i)
        local require_name = find_require_mod_name(bufnr, node)
        if require_name then
          section_started = true
          table.insert(requires, { name = require_name, node = node })
        else
          if section_started then break end
        end
      end
    end
    if #requires < 2 then return jelly.info("no need to sort requires") end

    do
      start_line = requires[1].node:range()
      _, _, stop_line = requires[#requires].node:range()
      stop_line = stop_line + 1
    end

    do ---ensure each require is the only node in its range
      for _, r in ipairs(requires) do
        local i = r.node

        local p = i:prev_sibling()
        if p ~= nil then
          local _, _, p_stop_line = p:range()
          local i_start_line = i:range()
          if p_stop_line == i_start_line then return jelly.fatal("unreachable", "%d line has a non-require node and a require node", i_start_line + 1) end
        end

        local n = i:next_sibling()
        if n ~= nil then
          local n_start_line = n:range()
          local _, _, p_stop_line = i:range()
          if p_stop_line == n_start_line then return jelly.fatal("unreachable", "%d line has a require node and a non-require node", p_stop_line + 1) end
        end
      end
    end

    tiers = sorted_tiers(requires)
  end

  local sorted_lines = {}
  do
    for requires in itertools.filter(tiers, function(requires) return #requires > 0 end) do
      for _, el in ipairs(requires) do
        table.insert(sorted_lines, nuts.get_1l_node_text(bufnr, el.node))
      end
      table.insert(sorted_lines, "")
    end
    assert(#sorted_lines > 1)
    ---the last line should not be blank
    table.remove(sorted_lines)
  end

  do
    local old_lines = buflines.iter(bufnr, start_line, stop_line)
    local no_changes = itertools.equals(sorted_lines, old_lines)
    if no_changes then return jelly.debug("no changes in the require section") end
  end

  buflines.replaces(bufnr, start_line, stop_line, sorted_lines)
  regulator:update(bufnr)
end
