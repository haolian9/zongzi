local M = {}

local builtin_fuzzymatch = require("infra.builtin_fuzzymatch")

local function enum_values(provider)
  local pt = type(provider)
  if pt == "function" then return provider() end
  if pt == "table" then return provider end
  error("unreachable")
end

---@param provider string[]|fun(): string[]
---@return fun(prompt: string): string[]
function M.constant(provider)
  local enum

  return function(prompt)
    if enum == nil then enum = assert(enum_values(provider)) end
    if #enum == 0 then return {} end
    if #prompt == 0 then return enum end
    return builtin_fuzzymatch(enum, prompt, { sort = false })
  end
end

---@param provider fun(): string[]
---@return fun(prompt: string): string[]
function M.variable(provider)
  return function(prompt)
    local enum = enum_values(provider)
    if #enum == 0 then return {} end
    if #prompt == 0 then return enum end
    return builtin_fuzzymatch(enum, prompt, { sort = false })
  end
end

return M
