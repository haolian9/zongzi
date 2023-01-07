local api = vim.api

-- sample parsed cmd
-- {
--   addr = "?",
--   args = {},
--   bang = false,
--   cmd = "split",
--   magic = {
--     bar = true,
--     file = true
--   },
--   mods = {
--     browse = false,
--     confirm = false,
--     emsg_silent = false,
--     filter = {
--       force = false,
--       pattern = ""
--     },
--     hide = false,
--     horizontal = false,
--     keepalt = false,
--     keepjumps = false,
--     keepmarks = false,
--     keeppatterns = false,
--     lockmarks = false,
--     noautocmd = false,
--     noswapfile = false,
--     sandbox = false,
--     silent = false,
--     split = "aboveleft",
--     tab = -1,
--     unsilent = false,
--     verbose = -1,
--     vertical = false
--   },
--   nargs = "?",
--   nextcmd = "",
--   range = {}
-- }

-- todo: lru?
local cache = {
  store = {},
}

---@param key string
---@return any?
function cache:get(key)
  return self.store[key]
end

function cache:set(key, val)
  self.store[key] = val
end

-- designed usecases, otherwise please use api.nvim_cmd directly
-- * ("silent write")
-- * ("help", string.format("luaref-%s", keyword))
---@param cmd string
---@param ... string|number
---@return string
return function(cmd, ...)
  local parsed

  if select("#", ...) > 0 then
    parsed = { cmd = cmd, args = { ... } }
  else
    parsed = cache:get(cmd)
    if parsed == nil then
      parsed = api.nvim_parse_cmd(cmd, {})
      cache:set(cmd, parsed)
    end
  end

  return api.nvim_cmd(parsed, { output = false })
end
