local M = {}

local feedkeys = require("infra.feedkeys")
local vsel = require("infra.vsel")

local function get_sel_text()
  local text = vsel.oneline_text()
  if text == nil then return end
  assert(text ~= "")

  return vim.fn.escape(text, [[.$*~\/]])
end

-- the vmap version *
function M.search_forward()
  local text = get_sel_text()
  if text == nil then return end

  vim.fn.setreg([[/]], text)
  feedkeys([[/<cr>]], "n")
end

-- the vmap version #
function M.search_backward()
  local text = get_sel_text()
  if text == nil then return end

  vim.fn.setreg([[/]], text)
  feedkeys([[?<cr>]], "n")
end

-- the vmap version :s
function M.substitute()
  local text = get_sel_text()
  if text == nil then return end

  vim.fn.setreg([["]], text)
  feedkeys([[:%s/<c-r>"/]], "n")
end

return M
