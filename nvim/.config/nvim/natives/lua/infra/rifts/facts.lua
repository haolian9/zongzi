local M = {}

local highlighter = require("infra.highlighter")
local ni = require("infra.ni")

do
  local ns = ni.create_namespace("infra.rifts")
  local hi = highlighter(ns)
  if vim.go.background == "light" then
    hi("NormalFloat", { fg = 8 })
    hi("WinSeparator", { fg = 243 })
  else
    hi("NormalFloat", { fg = 7 })
    hi("WinSeparator", { fg = 243 })
  end
  M.ns = ns
end

return M
