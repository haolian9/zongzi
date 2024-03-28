local dictlib = require("infra.dictlib")

local api = vim.api

local cache = dictlib.CappedDict(512)

-- designed usecases, otherwise please use api.nvim_cmd directly
-- * ("silent write")
-- * ("help", string.format("luaref-%s", keyword))
-- known bugs
-- * <leader>, <localleader>
-- * ('ll', 1); `cc` as well
-- * ('copen', 10)
---@param cmd string
---@param ... string|number
---@return string
return function(cmd, ...)
  local parsed

  if select("#", ...) > 0 then
    parsed = { cmd = cmd, args = { ... } }
  else
    parsed = cache[cmd]
    if parsed == nil then
      parsed = api.nvim_parse_cmd(cmd, {})
      cache[cmd] = parsed
    end
  end

  return api.nvim_cmd(parsed, { output = false })
end
