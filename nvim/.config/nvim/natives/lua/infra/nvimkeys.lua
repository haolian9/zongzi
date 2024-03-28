-- nvim_replace_termcodes has a mysterious signature

local dictlib = require("infra.dictlib")

local api = vim.api

local cache = dictlib.CappedDict(512)

--cached nvim_replace_termcodes with:
--* from_part=true
--* do_lt=false
--* special=true
---@param vim_keys string
---@return string
return function(vim_keys)
  local found = cache[vim_keys]
  if found then return found end

  local missing = api.nvim_replace_termcodes(vim_keys, true, false, true)
  cache[vim_keys] = missing
  return missing
end
