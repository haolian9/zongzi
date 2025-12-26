local M = {}

local highlighter = require("infra.highlighter")
local ni = require("infra.ni")

do
  local ns = ni.create_namespace("squirrel.whereami")
  local hi = highlighter(ns)
  if vim.go.background == "light" then
    hi("NormalFloat", { fg = 1, bold = true })
  else
    hi("NormalFloat", { fg = 1, bold = true })
  end

  M.floatwin_ns = ns
end

return M
