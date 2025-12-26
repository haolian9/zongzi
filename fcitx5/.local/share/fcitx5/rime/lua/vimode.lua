--original version: https://zhuanlan.zhihu.com/p/654489636
--
--lua_processor: https://github.com/hchunhui/librime-lua/wiki/Scripting#lua_processor
--* 0 表示 kRejected，声称本组件和其他组件都不响应该输入事件，立刻结束 processors 流程，交还由系统按默认方式响应（ASCII字符上屏、方向翻页等功能键作用于客户程序或系统全局……）。注意：如果 processor 已响应该输入事件但返回 kRejected，一次按键会接连生效两次。
--* 1 表示 kAccepted，声称本函数已响应该输入事件，结束 processors 流程，之后的组件和系统都不得响应该输入事件。注意：如果 processor 未响应该输入事件但返回 kAccepted，相当于禁用这个按键
--* 2 表示 kNoop，声称本函数不响应该输入事件，交给接下来的 processors 决定。注意：如果 processor 已响应该输入事件但返回 kNoop，一次按键可能会接连生效多次。如果所有 processors 都返回kNoop，则交还由系统按默认方式响应。

---@class RimeContext
---@field get_option fun(self, name: string): boolean
---@field set_option fun(self, name: string, val: boolean)

local triggers = {
  ["Escape"] = true,
  ["Control+bracketleft"] = true,
  ["Control+c"] = true,
  ["Control+o"] = true,
}

---@param input string @see more keys in `xmodmap -pke`
---@param ctx RimeContext
local function goto_ascii(input, ctx)
  if not triggers[input] then return end
  if ctx:get_option("ascii_mode") then return end

  ctx:set_option("ascii_mode", true)
end

return function(key_event, env)
  goto_ascii(key_event:repr(), env.engine.context)
  return 2 --this processor will passthrough all the key_events
end
