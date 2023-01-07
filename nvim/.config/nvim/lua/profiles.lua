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

  -- tier 0
  presets["base"] = enum()
  presets["plug"] = enum()
  presets["viz"] = enum()
  presets["joy"] = enum()
  presets["gui"] = enum()
  -- tier 1
  presets["git"] = enum("base")
  presets["wiki"] = enum("base")
  presets["lsp"] = enum("base")
  presets["treesitter"] = enum("base")
  -- tier 2
  presets["code"] = enum("treesitter", "lsp")
  -- tier 3
  presets["python"] = enum("code")
  presets["zig"] = enum("code")
  presets["lua"] = enum("code")
  presets["go"] = enum("code")
  presets["rust"] = enum("code")
  presets["nim"] = enum("code")
  presets["ansible"] = enum("code")
  presets["php"] = enum("code")
  presets["clang"] = enum("code")
  presets["fennel"] = enum("code")
  presets["bash"] = enum("code")
  -- tier 4
  presets["mostbeloved"] = enum("python", "zig", "lua", "clang")
  presets["python.jedi"] = enum()
end

local default = bit.bor(presets.base, presets.plug, presets.joy)
local final = default

local function has(val)
  return bit.band(final, val) == val
end

---@param literals string @a,b,c
function M.init(literals)
  assert(literals ~= nil)
  assert(final == default, "can only be initialized once")

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

function M.from_env()
  local literals = os.getenv("NVIM_PROFILES") or os.getenv("nvim_profiles")
  if literals ~= nil then M.init(literals) end
  return M
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
    table.sort(sorted, function(a, b)
      return a[1] <= b[1]
    end)
  end

  local result = {}
  for _, el in ipairs(sorted) do
    table.insert(result, el[2])
  end

  return table.concat(result, ",")
end

function M.asint(...)
  local exclude = { ... }
  local result = final

  for _, lit in ipairs(exclude) do
    local val = presets[lit]
    if val == nil then error(string.format("no such profile: %s", lit)) end
    result = bit.band(result, bit.bnot(val))
  end

  return result
end

function M.inspect()
  local sorted = {}
  for lit, val in pairs(presets) do
    table.insert(sorted, { val, lit })
  end
  table.sort(sorted, function(a, b)
    return a[1] <= b[1]
  end)
  return vim.json.encode(sorted)
end

function M.test()
  assert(final == default, "profiles has been initialized")
  M.init("git,zig")
  assert(M.has("base") and M.has("git") and M.has("code") and M.has("zig"))
  assert(not (M.has("python") or M.has("wiki")))
end

return M
