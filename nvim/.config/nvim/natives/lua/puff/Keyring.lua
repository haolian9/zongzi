local itertools = require("infra.itertools")

---@class puff.Keyring
---@field list string[]
---@field private dict {[string]: integer}
local Keyring = {}
do
  Keyring.__index = Keyring

  ---@param key string
  ---@return integer?
  function Keyring:index(key) return self.dict[key] end
end

---@param keys string @printable ascii key string
---@return puff.Keyring
return function(keys)
  local list = {}
  local dict = {}
  do
    for i = 1, #keys do
      local char = string.sub(keys, i, i)
      list[i] = char
      dict[char] = i
    end
    assert(not itertools.contains(list, "q"), "q is reserved for quit")
  end

  return setmetatable({ list = list, dict = dict }, Keyring)
end
