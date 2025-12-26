local M = {}

local bufmap = require("infra.keymap.buffer")
local mi = require("infra.mi")
local ni = require("infra.ni")

local render = require("guwen.render")
local sources = require("guwen.sources")

local lastwin

local function need_close_lastwin()
  if lastwin == nil then return false end
  if not ni.win_is_valid(lastwin) then return false end
  ---if lastwin is landed, leave it to user
  if mi.win_is_landed(lastwin) then return false end
  return true
end

local function Open(src_name)
  local open
  open = function()
    if need_close_lastwin() then ni.win_close(lastwin, true) end
    local max_width, max_height = vim.go.columns, vim.go.lines
    local winid, bufnr = render(max_width, max_height, sources[src_name](max_width))
    local bm = bufmap.wraps(bufnr)
    bm.n("gn", open)
    lastwin = winid
  end
  return open
end

M["唐诗一首"] = Open("唐诗三百首")
M["宋词一首"] = Open("宋词三百首")
M["楚辞一篇"] = Open("楚辞")
M["古文一篇"] = Open("古文观止")
M["诗经一篇"] = Open("诗经")
M["论语一篇"] = Open("论语")

M.comp = {}
do
  function M.comp.available_sources()
    local names = {}
    for key in pairs(M) do
      if key ~= "comp" then table.insert(names, key) end
    end
    return names
  end
end

return M
