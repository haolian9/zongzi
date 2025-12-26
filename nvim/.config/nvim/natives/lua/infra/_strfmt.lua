local setlib = require("infra.setlib")
local strlib = require("infra.strlib")

local inspect_opts = { newline = " ", indent = "" }
local scalars = setlib.new("boolean", "number", "string")

---@param format string
---@param ... any
---@return string
return function(format, ...)
  local args = {}
  for i = 1, select("#", ...) do
    local arg = select(i, ...)
    local repr = arg
    if not scalars[type(arg)] then repr = vim.inspect(arg, inspect_opts) end
    args[i] = repr
  end

  if #args ~= 0 then return string.format(format, unpack(args)) end

  assert(format ~= nil, "missing format")
  if not strlib.contains(format, "%s") then return format end
  error("unmatched args for format")
end
