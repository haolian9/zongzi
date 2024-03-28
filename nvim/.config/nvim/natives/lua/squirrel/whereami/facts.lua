local M = {}

local highlighter = require("infra.highlighter")

local api = vim.api

do
  local ns = api.nvim_create_namespace("squirrel.whereami")
  local hi = highlighter(ns)
  if vim.go.background == "light" then
    hi("NormalFloat", { fg = 1, bold = true })
  else
    hi("NormalFloat", { fg = 1, bold = true })
  end

  M.floatwin_ns = ns
end

return M
