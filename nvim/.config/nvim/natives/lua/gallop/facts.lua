local M = {}

local fn = require("infra.fn")
local highlighter = require("infra.highlighter")

local api = vim.api

do
  local list = {}
  local dict = {}
  do
    local str = table.concat({
      "asdfjkl;" .. "gh" .. "qwertyuiop" .. "zxcvbnm",
      ",./'[" .. "]1234567890-=",
      "ASDFJKL" .. "GH" .. "WERTYUIOP" .. "ZXCVBNM",
    }, "")
    for i = 1, #str do
      local char = string.sub(str, i, i)
      list[i] = char
      dict[char] = i
    end
  end

  M.labels = {
    index = function(label) return dict[label] end,
    iter = function() return fn.iter(list) end,
  }
end

do
  M.label_ns = api.nvim_create_namespace("gallop.labels")
  do
    local hi = highlighter(0)
    if vim.go.background == "light" then
      hi("GallopStop", { fg = 15, bg = 8, bold = true })
    else
      hi("GallopStop", { fg = 8, bg = 15, bold = true })
    end
  end
end

return M
