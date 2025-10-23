local M = {}

local highlighter = require("infra.highlighter")
local ni = require("infra.ni")

M.anchor_ns = ni.create_namespace("ido:anchors")

do
  local hi = highlighter(0)
  if vim.go.background == "light" then
    hi("IdoTruth", { bg = 15, fg = 9, bold = true })
    hi("IdoReplica", { bg = 222, fg = 0 })
  else
    hi("IdoTruth", { bg = 0, fg = 9, bold = true })
    hi("IdoReplica", { bg = 3, fg = 15 })
  end
end

return M
