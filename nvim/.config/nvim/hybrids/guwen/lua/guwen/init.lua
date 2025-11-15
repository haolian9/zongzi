local M = {}

local ni = require("infra.ni")

local render = require("guwen.render")
local sources = require("guwen.sources")

local last_win

local function entrypoint(src_name)
  return function()
    if last_win ~= nil and ni.win_is_valid(last_win) then ni.win_close(last_win, true) end
    local host_win_id = ni.get_current_win()
    local win_width = ni.win_get_width(host_win_id)
    local win_height = ni.win_get_height(host_win_id)
    last_win = render(win_width, win_height, sources[src_name](win_width))
  end
end

M["唐诗一首"] = entrypoint("唐诗三百首")
M["宋词一首"] = entrypoint("宋词三百首")
M["楚辞一篇"] = entrypoint("楚辞")
M["古文一篇"] = entrypoint("古文观止")
M["诗经一篇"] = entrypoint("诗经")
M["论语一篇"] = entrypoint("论语")

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
