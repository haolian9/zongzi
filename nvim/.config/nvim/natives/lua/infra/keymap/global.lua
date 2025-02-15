local jelly = require("infra.jellyfish")("infra.keymap.global")
local ni = require("infra.ni")

---@param mode string
---@param lhs string
---@param rhs string|fun()
local function noremap(mode, lhs, rhs)
  if mode == "v" then error("use x+s instead") end

  local rhs_type = type(rhs)
  if rhs_type == "function" then
    ni.set_keymap(mode, lhs, "", { silent = false, noremap = true, callback = rhs })
  elseif rhs_type == "string" then
    ni.set_keymap(mode, lhs, rhs, { silent = false, noremap = true })
  else
    error(string.format("unexpected rhs type: %s", rhs_type))
  end
end

do
  ---@overload fun(modes: string|string[], lhs: string, rhs: string|fun())
  local mapper = setmetatable({
    n = function(lhs, rhs) noremap("n", lhs, rhs) end,
    v = function(lhs, rhs) noremap("v", lhs, rhs) end,
    i = function(lhs, rhs) noremap("i", lhs, rhs) end,
    t = function(lhs, rhs) noremap("t", lhs, rhs) end,
    c = function(lhs, rhs) noremap("c", lhs, rhs) end,
    x = function(lhs, rhs) noremap("x", lhs, rhs) end,
    o = function(lhs, rhs) noremap("o", lhs, rhs) end,
    s = function(lhs, rhs) noremap("s", lhs, rhs) end,
  }, {
    __call = function(_, modes, lhs, rhs)
      if type(modes) == "string" then return noremap(modes, lhs, rhs) end
      for _, mode in ipairs(modes) do
        noremap(mode, lhs, rhs)
      end
    end,
  })

  return mapper
end
