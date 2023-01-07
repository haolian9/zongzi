local nuls = require("null-ls")
local enchant = require("xnuls.utils.enchant")
local fn = require("infra.fn")

local Kind = vim.lsp.protocol.CompletionItemKind

local object_completer_factory = function(object)
  local cache = nil
  local kind_map = {
    ["function"] = Kind["Function"],
    ["table"] = Kind["Module"],
    ["boolean"] = Kind["Variable"],
    ["string"] = Kind["Variable"],
    ["number"] = Kind["Variable"],
    ["userdata"] = Kind["Variable"],
  }
  local function load_candidates()
    if cache == nil then
      cache = {}
      for name, val in pairs(object) do
        local kind = kind_map[type(val)]
        assert(kind ~= nil, string.format("unexpected kind of %s.%s: %s", object, name, type(val)))
        cache[name] = kind
      end
      assert(#cache <= 1024, string.format("too much nvim fn to cache for %s", object))
    end
    return cache
  end

  ---@param prefix string
  ---@return nil|table
  local function get_candidates(prefix)
    if type(object) ~= "table" then return end
    local no_prefix = prefix == "" or prefix == nil
    local items = {}
    for name, kind in pairs(load_candidates()) do
      if no_prefix or vim.startswith(name, prefix) then table.insert(items, {
        label = name,
        kind = kind,
      }) end
    end
    return items
  end

  return get_candidates
end

-- for {api,uv}.*
local try_objects = (function()
  local roots = { api = vim.api, uv = vim.loop, lsp = vim.lsp }
  -- {vim.x.y.z: object_completer}
  local nodes = {}

  local function try(params, spell)
    local _ = params
    local names
    do
      if spell == nil then return end
      names = fn.split(spell, ".")
      if #names < 2 then return end
    end

    local completer
    do
      local root = roots[names[1]]
      if root == nil then return end

      local node = root
      for i = 2, #names - 1 do
        node = node[names[i]]
        if node == nil then return end
      end

      completer = object_completer_factory(node)
      if completer == nil then return end

      local level = #names
      local key = fn.join(fn.slice(names, 1, level - 1), ".")
      if nodes[level] == nil then
        nodes[level] = { [key] = completer }
      else
        nodes[level][key] = completer
      end
    end

    return completer(names[#names])
  end

  return try
end)()

local function complete(params, done)
  local spell = enchant.lua_spell(params)

  for _, try in pairs({ try_objects }) do
    local items = try(params, spell)
    if items ~= nil then
      done({ { items = items, isIncomplete = false } })
      return
    end
  end

  done({ { items = {}, isIncomplete = false } })
end

return {
  name = "lua-nvimapi",
  method = nuls.methods.COMPLETION,
  filetypes = { "lua", "fennel" },
  generator = {
    fn = complete,
    async = true,
    copy_params = false,
  },
}
