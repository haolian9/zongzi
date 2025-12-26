local M = {}

local builtin_fuzzymatch = require("infra.builtin_fuzzymatch")
local its = require("infra.its")

---@param flag string
---@param provider string[]|fun(): string[]
---@return string[]
local function enum_values(flag, provider)
  return its(type(provider) == "function" and provider() or provider) --
    :map(function(i) return string.format("--%s=%s", flag, i) end)
    :tolist()
end

---@param provider string[]|fun(): string[]
---@return fun(prompt: string): string[]
function M.constant(flag, provider)
  local enum

  return function(prompt)
    if enum == nil then enum = assert(enum_values(flag, provider)) end
    if #enum == 0 then return {} end

    if #prompt == 0 then return enum end

    return builtin_fuzzymatch(enum, prompt, { sort = false })
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
    return builtin_fuzzymatch(enum, prompt, { sort = false })
  end
end

return M
