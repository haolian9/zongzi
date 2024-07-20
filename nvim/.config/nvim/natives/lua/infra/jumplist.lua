local M = {}

local ex = require("infra.ex")

--a known bug: https://github.com/neovim/neovim/issues/17861
function M.push_here() ex.eval("normal! m`") end

return M
