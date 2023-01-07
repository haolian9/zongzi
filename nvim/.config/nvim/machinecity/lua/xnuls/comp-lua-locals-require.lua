local Kind = vim.lsp.protocol.CompletionItemKind

local nuls = require("null-ls")

local fn = require("infra.fn")
local disinter = require("xnuls.utils.disinter")
local enchant = require("xnuls.utils.enchant")

local load_candidates = (function()
  local cache = {}

  return function(mod_path)
    local submods = cache[mod_path]

    if submods ~= nil then return submods end

    submods = fn.concrete(disinter.local_submods(mod_path))
    cache[mod_path] = submods

    return submods
  end
end)()

local function get_candidates(text)
  local names = fn.split(text, ".")

  -- input: ''
  if #names < 2 then return { { label = "infra", kind = Kind["module"] } } end

  -- input: 'infra.'
  if names[1] ~= "infra" then return end

  local items = {}
  do
    local prefix = assert(fn.pop(names))
    local mod_path = fn.join(names, "/")
    local submods = load_candidates(mod_path)

    local prefix_none = prefix == ""
    for name in fn.list_iter(submods) do
      if prefix_none or vim.startswith(name, prefix) then table.insert(items, { label = name, kind = Kind["Module"] }) end
    end
  end

  return items
end

local function complete(params, done)
  -- more expensive way
  --local text = require_text_via_treesitter()
  local text = enchant.lua_spell_of_require(params)
  if text == nil then
    done({ { items = {}, isIncomplete = false } })
    return
  end

  local items = get_candidates(text) or {}
  done({ { items = items, isIncomplete = false } })
end

return {
  name = "lua-require",
  method = nuls.methods.COMPLETION,
  filetypes = { "lua", "fennel" },
  generator = {
    fn = complete,
    async = true,
    copy_params = false,
  },
}
