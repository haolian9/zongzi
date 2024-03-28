local M = {}

local fn = require("infra.fn")
local strlib = require("infra.strlib")

---@param flag string
---@param provider string[]|fun(): string[]
---@return string[]
local function enum_values(flag, provider)
  return fn.tolist(fn.map(
    function(i) return string.format("--%s=%s", flag, i) end,
    (function()
      local pt = type(provider)
      if pt == "function" then return provider() end
      if pt == "table" then return provider end
      error("unreachable: " .. pt)
    end)()
  ))
end

---@param provider string[]|fun(): string[]
---@return fun(prompt: string): string[]
function M.constant(flag, provider)
  local enum

  return function(prompt)
    if enum == nil then enum = assert(enum_values(flag, provider)) end
    if #enum == 0 then return {} end

    if #prompt == 0 then return enum end
    return fn.tolist(fn.filter(function(i) return strlib.startswith(i, prompt) end, enum))
  end
end

---@param flag string
---@param provider fun(): string[]
---@return fun(prompt: string): string[]
function M.variable(flag, provider)
  return function(prompt)
    local enum = enum_values(flag, provider)
    if #enum == 0 then return {} end
    if #prompt == 0 then return enum end
    return fn.tolist(fn.filter(function(i) return strlib.startswith(i, prompt) end, enum))
  end
end

return M
