-- provides profiles for loading plugins, configuring plugins
--
-- * presets: preset profiles, inheritable
-- * final: final profiles presented as number
-- * NVIM_PFOEILES: env var
-- * minimal profile: base
-- * special profile: all # mainly for PluginInstall/Update

local M = {}

local presets = {}
do
  local wise = (function()
    local count = 0
    return function()
      assert(count <= 30, "reached 30 limit")
      local result = count
      count = count + 1
      return result
    end
  end)()

  ---@vararg string @list of base
  local function enum(...)
    local val = bit.lshift(1, wise())
    for _, base in ipairs({ ... }) do
      local base_val = presets[base]
      assert(base_val ~= nil, string.format("need to declare base (%s) first", base))
      val = bit.bor(val, base_val)
    end
    return val
  end

  --stylua: ignore
  do
    --tier0
    presets["base"]      = enum()
    --tier1
    presets["halhacks"]  = enum("base")
    presets["joy"]       = enum("base")
    presets["powersave"] = enum("base")
    presets["lsp"]       = enum("base")
    presets["treesit"]   = enum("base")
    --tier2
    presets["coding"]    = enum("halhacks", "joy", "lsp", "treesit")
    presets["editing"]   = enum("joy")
  end
end

local final = bit.bor(presets.base, 0)

local function has(val) return bit.band(final, val) == val end

function M.init()
  M.init = nil

  -- format: "a,b"
  local literals = os.getenv("NVIM_PROFILES") or os.getenv("nvim_profiles")
  if literals == nil then return end

  if literals == "all" then
    for _, val in pairs(presets) do
      final = bit.bor(final, val)
    end
    return
  end

  local lits = vim.split(literals, ",")
  for _, lit in ipairs(lits) do
    local val = presets[lit]
    assert(val ~= nil, "unknown profile: " .. lit)
    final = bit.bor(final, val)
  end
end

function M.has(literal)
  local val = presets[literal]
  assert(val ~= nil, "unknown profile: " .. literal)
  return has(val)
end

function M.aslist()
  local sorted = {}
  do
    for lit, val in pairs(presets) do
      if has(val) then table.insert(sorted, { val, lit }) end
    end
    table.sort(sorted, function(a, b) return a[1] <= b[1] end)
  end

  local result = {}
  for i, el in ipairs(sorted) do
    result[i] = el[2]
  end

  return result
end

return M
