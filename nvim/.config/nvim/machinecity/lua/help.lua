local M = {}

-- solution 1: api.nvim_input([[<c-u>:h <c-r><c-w><cr>]])
-- solution 2: vim.fn.expand('<cword>')

local vsel = require("infra.vsel")
local ex = require("infra.ex")

M.nvim = function(keyword)
  if keyword == nil then keyword = vsel.oneline_text() end
  if keyword == nil then return end
  ex("help", keyword)
end

M.luaref = function(keyword)
  if keyword == nil then keyword = vsel.oneline_text() end
  if keyword == nil then return end
  ex("help", string.format("luaref-%s", keyword))
end

return M
