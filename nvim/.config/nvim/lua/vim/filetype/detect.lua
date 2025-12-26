-- the original vim.filetype.detect is just overkill, filetype.lua is good enough for me

local function nop() end

return setmetatable({}, {
  __index = function() return nop end,
})
