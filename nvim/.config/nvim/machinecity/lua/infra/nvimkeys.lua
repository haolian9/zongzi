-- nvim_replace_termcodes has a mysterious signature

local api = vim.api

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

--cached nvim_replace_termcodes with:
--* from_part=true
--* do_lt=false
--* special=true
---@param vim_keys string
---@return string
return function(vim_keys)
  local found = cache:get(vim_keys)
  if found then return found end

  local missing = api.nvim_replace_termcodes(vim_keys, true, false, true)
  cache:set(vim_keys, missing)
  return missing
end
