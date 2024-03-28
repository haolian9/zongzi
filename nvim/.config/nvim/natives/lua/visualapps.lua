local M = {}

local ex = require("infra.ex")
local nvimkeys = require("infra.nvimkeys")
local vsel = require("infra.vsel")

local api = vim.api

-- the vmap version *
function M.search_forward()
  local text = vsel.oneline_escaped()
  if text == "" then return end

  vim.fn.setreg([[/]], text)
  api.nvim_feedkeys(nvimkeys([[/<cr>]]), "n", false)
end

-- the vmap version #
function M.search_backward()
  local text = vsel.oneline_escaped()
  if text == nil then return end

  vim.fn.setreg([[/]], text)
  api.nvim_feedkeys(nvimkeys([[?<cr>]]), "n", false)
end

-- the vmap version :s
function M.substitute()
  local text = vsel.oneline_escaped()
  if text == nil then return end

  vim.fn.setreg([["]], text)
  api.nvim_feedkeys(nvimkeys([[:%s/<c-r>"/]]), "n", false)
end

function M.vimgrep()
  local text = vsel.oneline_escaped()
  if text == "" then return end

  ex(string.format("lvimgrep /%s/ %%", text))
  require("sting.toggle").open_locwin()
end

return M
