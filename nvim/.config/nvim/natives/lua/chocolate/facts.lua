local M = {}

local highlighter = require("infra.highlighter")

M.palette = {
  { 203, 88 }, -- 赤：珊瑚红 + 深酒红 - 现代红系
  { 214, 94 }, -- 橙：琥珀橙 + 深紫红 - 活力橙系
  { 226, 100 }, -- 黄：亮黄色 + 深紫灰 - 醒目黄系
  { 85, 28 }, -- 绿：青绿色 + 深橄榄绿 - 自然绿系
  { 81, 24 }, -- 青：亮青色 + 深海蓝绿 - 科技青系
  { 39, 19 }, -- 蓝：天蓝色 + 深海蓝 - 冷静蓝系
  { 141, 55 }, -- 紫：薰衣草紫 + 深褐紫 - 优雅紫系
}

M.higroups = {}
local hi = highlighter(0)
for i, pair in ipairs(M.palette) do
  local hig = "Chocolate." .. i
  hi(hig, { fg = pair[2], bg = pair[1] })
  M.higroups[i] = hig
end

return M
