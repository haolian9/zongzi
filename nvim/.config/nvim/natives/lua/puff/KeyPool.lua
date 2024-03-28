local fn = require("infra.fn")

---@class puff.KeyPool
---@field private list string[]
---@field private dict {[string]: integer}
local KeyPool = {}
do
  KeyPool.__index = KeyPool

  ---@param key string
  ---@return integer?
  function KeyPool:index(key) return self.dict[key] end

  ---@return fun(): string?
  function KeyPool:iter() return fn.iter(self.list) end
end

---@param keys string @printable ascii key string
---@return puff.KeyPool
return function(keys)
  local list = {}
  local dict = {}
  do
    for i = 1, #keys do
      local char = string.sub(keys, i, i)
      list[i] = char
      dict[char] = i
    end
    assert(not fn.contains(list, "q"), "q is reserved for quit")
  end

  return setmetatable({ list = list, dict = dict }, KeyPool)
end
