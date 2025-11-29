local M = {}

local awful = require("awful")

do
  ---spawn external programs without startup notification
  ---@param fmt string
  ---@param ... any
  local function spawn(fmt, ...) awful.spawn.spawn(string.format(fmt, ...), false) end

  function M.autostart(facts)
    spawn("xbindkeys -f %s/xwindow/xbindkeys.awesome", facts.xdg)
    spawn("libinput-gestures")

    -- spawn("fcitx5")
    -- spawn("dunst")
    -- spawn("xrandr --output eDP-1 --off")
  end
end

return M

