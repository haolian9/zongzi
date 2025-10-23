local M = {}

local highlighter = require("infra.highlighter")
local itertools = require("infra.itertools")
local ni = require("infra.ni")

do
  local list = {}
  local dict = {}
  do
    local str = table.concat({
      "asdfjkl;" .. "gh" .. "qwertyuiop" .. "zxcvbnm",
      ",./'[" .. "]1234567890-=",
      "ASDFJKL" .. "GH" .. "QWERTYUIOP" .. "ZXCVBNM",
    }, "")
    for i = 1, #str do
      local char = string.sub(str, i, i)
      list[i] = char
      dict[char] = i
    end
  end

  M.labels = {
    index = function(label) return dict[label] end,
    iter = function() return itertools.iter(list) end,
  }
end

do
  M.label_ns = ni.create_namespace("gallop.labels")
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
