local M = {}

-- solution 1: vim.api.nvim_input([[<c-u>:h <c-r><c-w><cr>]])
-- solution 2: vim.fn.expand('<cword>')

local ex = require("infra.ex")
local vsel = require("infra.vsel")

function M.nvim(keyword)
  if keyword == nil then keyword = vsel.oneline_text() end
  if keyword == nil then return end
  ex("help", keyword)
end

function M.luaref(keyword)
  if keyword == nil then keyword = vsel.oneline_text() end
  if keyword == nil then return end
  ex("help", string.format("luaref-%s", keyword))
end

return M
