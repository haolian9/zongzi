--notes:
--* this rc.lua is based on /etc/xdg/awesome/rc.lua
--* the runtime files lay in /usr/share/awesome/lib
--* use xev to get keycodes, rather than showkey

local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local naughty = require("naughty")
local wibox = require("wibox")

local capi = {
  ---@diagnostic disable-next-line: undefined-global
  client = client,
  ---@diagnostic disable-next-line: undefined-global
  mouse = mouse,
  ---@diagnostic disable-next-line: undefined-global
  screen = screen,
  ---@diagnostic disable-next-line: undefined-global
  awesome = awesome,
}

local facts = {
  --Mod1=alt, Mod4=super, Shift, Control
  modkey = "Mod4",
  terminal = os.getenv("TERMINAL") or "urxvt",
  xdg = assert(os.getenv("HOME")) .. "/.config",
  background = "#073642",
  --hardcode, can not be changed
  ntags = 3,
}

---each subkey is prefixed by facts.modkey
---@param lhs string|string[]
---@param rhs any
local function subkey(lhs, rhs)
  local unpack = unpack or table.unpack

  local mods, key
  if type(lhs) == "string" then
    mods = {}
    key = lhs
  elseif type(lhs) == "table" then
    mods = gears.table.clone(lhs, false)
    key = table.remove(mods, #mods)
  else
    error("unreachable")
  end

  return awful.key({ facts.modkey, unpack(mods) }, key, rhs)
end

local btncode, btnname
do
  ---@alias Btn 'left'|'right'|'middle'|'scrollup'|'scrolldown'

  local codes = { left = 1, right = 3, middle = 2, scrollup = 4, scrolldown = 5 }

  local names = {}
  for key, val in pairs(codes) do
    names[val] = key
  end

  ---@param name Btn
  ---@return integer
  function btncode(name) return assert(codes[name]) end

  ---@param code integer
  ---@return Btn
  function btnname(code) return assert(names[code]) end
end

---@param btn Btn
---@param rhs fun()
local function mousekey(btn, rhs) return awful.button({}, btncode(btn), rhs) end

local rclocal
do
  local ok, chunk = pcall(loadfile, facts.xdg .. "/awesome/local.lua")
  if ok and chunk ~= nil then
    rclocal = chunk()
  else
    ---@diagnostic disable
    rclocal = { autostart = function(facts) end }
  end
end

do -- Error handling
  if capi.awesome.startup_errors then naughty.notify({ preset = naughty.config.presets.critical, title = "Oops, there were errors during startup!", text = capi.awesome.startup_errors }) end

  do -- Handle runtime errors after startup
    local in_error = false
    capi.awesome.connect_signal("debug::error", function(err)
      -- Make sure we don't go into an endless error loop
      if in_error then return end
      in_error = true

      naughty.notify({ preset = naughty.config.presets.critical, title = "Oops, an error happened!", text = tostring(err) })
      in_error = false
    end)
  end
end

do --awesome's behavior
  --there's always a client that will have focus on events such as tag switching
  require("awful.autofocus")

  do --Themes define colours, icons, font and wallpapers.
    --source: /usr/share/awesome/themes/zenburn/theme.lua
    local zenburn = assert(dofile(gears.filesystem.get_themes_dir() .. "zenburn/theme.lua"))
    zenburn.font = "Monego 14"
    beautiful.init(zenburn)
  end

  --Table of layouts to cover with awful.layout.inc, order matters.
  awful.layout.layouts = {
    awful.layout.suit.fair,
    awful.layout.suit.fair.horizontal,
    awful.layout.suit.max,
  }
end

do --wibar for every screen
  local set_wallpaper
  if facts.background ~= nil then
    function set_wallpaper() gears.wallpaper.set(facts.background) end
  else
    function set_wallpaper(s)
      local wallpaper = beautiful.wallpaper
      if wallpaper == nil then return end
      if type(wallpaper) == "function" then wallpaper = wallpaper(s) end
      gears.wallpaper.maximized(wallpaper, s, true)
    end
  end

  local widgets = {}
  do
    widgets.systray = wibox.widget.systray()
    widgets.clock = wibox.widget.textclock("%H:%M")

    do
      local w = wibox.widget.textbox("p")
      local pause = false
      w:connect_signal("button::press", function(_, _, code)
        pause = not pause
        awful.spawn("videos " .. (pause and "pause" or "unpause"))
      end)
      widgets.mpv_play = w
    end

    do
      local w = wibox.widget.textbox("z")
      w:connect_signal("button::press", function()
        local curtag = assert(awful.screen.focused().selected_tag)
        for _, c in ipairs(curtag:clients()) do
          if c.minimized then c.minimized = false end
        end
      end)
      widgets.restore_minized = w
    end
  end

  local tags = {
    { layout = awful.layout.suit.fair },
    { layout = awful.layout.suit.max },
    { layout = awful.layout.suit.max },
  }

  --Create a wibox
  local taglist_buttons = gears.table.join(
    mousekey("left", function(t) t:view_only() end),
    mousekey("right", awful.tag.viewtoggle),
    mousekey("scrollup", function(t) awful.tag.viewprev(t.screen) end),
    mousekey("scrolldown", function(t) awful.tag.viewnext(t.screen) end),
    nil --
  )

  local tasklist_buttons = gears.table.join(
    mousekey("left", function(c)
      if c == capi.client.focus then
        c.minimized = true
      else
        c:emit_signal("request::activate", "tasklist", { raise = true })
      end
    end),
    mousekey("right", function() awful.menu.client_list({ theme = { width = 450 } }) end),
    mousekey("scrollup", function() awful.client.focus.byidx(-1) end),
    mousekey("scrolldown", function() awful.client.focus.byidx(1) end),
    nil --
  )

  --Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
  capi.screen.connect_signal("property::geometry", set_wallpaper)

  awful.screen.connect_for_each_screen(function(s)
    set_wallpaper(s)

    for key, props in ipairs(tags) do
      awful.tag.add(tostring(key), props)
    end

    --one layoutbox per screen.
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
      mousekey("scrolldown", function() awful.layout.inc(1) end),
      mousekey("scrollup", function() awful.layout.inc(-1) end),
      nil --
    ))

    s.mytaglist = awful.widget.taglist({ screen = s, filter = awful.widget.taglist.filter.all, buttons = taglist_buttons })
    s.mytasklist = awful.widget.tasklist({ screen = s, filter = awful.widget.tasklist.filter.currenttags, buttons = tasklist_buttons })

    s.mywibox = awful.wibar({ position = "bottom", screen = s })
    s.mywibox:setup({
      layout = wibox.layout.align.horizontal,
      spacing_widget = 10,
      {
        layout = wibox.layout.fixed.horizontal,
        s.mytaglist,
      },
      s.mytasklist,
      {
        layout = wibox.layout.fixed.horizontal,
        spacing = 5,
        widgets.systray,
        widgets.clock,
        widgets.mpv_play,
        widgets.restore_minized,
        s.mylayoutbox,
      },
    })
  end)
end

do --global bindings
  local keys = {}

  ---@param list any[]
  local function extends(list)
    for _, v in ipairs(list) do
      table.insert(keys, v)
    end
  end

  keys = gears.table.join(
    subkey("n", awful.tag.viewnext),
    subkey("p", awful.tag.viewprev),

    subkey("l", function() awful.client.focus.byidx(1) end),
    subkey("h", function() awful.client.focus.byidx(-1) end),
    subkey("j", function() awful.client.focus.byidx(1) end),
    subkey("k", function() awful.client.focus.byidx(-1) end),

    subkey({ "Control", "l" }, function() awful.client.swap.byidx(1) end),
    subkey({ "Control", "h" }, function() awful.client.swap.byidx(-1) end),
    subkey({ "Control", "j" }, function() awful.client.swap.byidx(1) end),
    subkey({ "Control", "k" }, function() awful.client.swap.byidx(-1) end),

    subkey("6", function()
      awful.client.focus.history.previous()
      if capi.client.focus then capi.client.focus:raise() end
    end),

    subkey("`", function() awful.spawn(facts.terminal) end),
    subkey("/", function() awful.spawn("rofi -show run") end),

    subkey("space", function() awful.layout.inc(1) end),
    subkey({ "Shift", "space" }, function() awful.layout.inc(-1) end),

    subkey({ "Control", "r" }, capi.awesome.restart), --impossible to keep variable during restarting
    subkey({ "Control", "q" }, capi.awesome.quit),

    nil --
  )

  keys = gears.table.join(
    keys,
    subkey("Right", function()
      capi.client.focus.fullscreen = false
      awful.client.focus.byidx(1)
      capi.client.focus.fullscreen = true
    end),
    subkey("Left", function()
      capi.client.focus.fullscreen = false
      awful.client.focus.byidx(-1)
      capi.client.focus.fullscreen = true
    end),
    subkey("Up", function() capi.client.focus.fullscreen = true end),
    subkey("Down", function() capi.client.focus.fullscreen = false end)
  )

  --what are these?
  keys = gears.table.join(
    keys,

    subkey("=", function() awful.tag.incmwfact(0.05) end),
    subkey("-", function() awful.tag.incmwfact(-0.05) end),
    subkey({ "Shift", "=" }, function() awful.tag.incnmaster(1, nil, true) end),
    subkey({ "Shift", "-" }, function() awful.tag.incnmaster(-1, nil, true) end),
    subkey({ "Control", "=" }, function() awful.tag.incncol(1, nil, true) end),
    subkey({ "Control", "-" }, function() awful.tag.incncol(-1, nil, true) end),

    nil --
  )

  extends(subkey("b", function()
    for s in capi.screen do
      s.mywibox.visible = not s.mywibox.visible
    end
  end))

  --notes: no focus change
  extends(subkey({ "Control", "z" }, function()
    local curtag = assert(awful.screen.focused().selected_tag)
    for _, c in ipairs(curtag:clients()) do
      if c.minimized then c.minimized = false end
    end
  end))

  --goto tag
  for i = 1, facts.ntags do
    extends(subkey(tostring(i), function()
      local screen = awful.screen.focused()
      local tag = screen.tags[i]
      if tag then tag:view_only() end
    end))
  end

  root.keys(keys)
end

do --global bindings - winmove mode
  local function notify(fmt, ...) naughty.notify({ title = "winmove mode", text = string.format(fmt, ...) }) end

  local function move_to_tag(index)
    return function()
      local wind = capi.client.focus
      if wind == nil then return notify("no window is being focused") end
      local tag = wind.screen.tags[index]
      if tag == nil then return notify("no tag is indiced as %s", index) end
      wind:move_to_tag(tag)
    end
  end

  local trigger = { { facts.modkey }, "m", function() notify("active") end }

  local keys = {}
  for i = 1, facts.ntags do
    table.insert(keys, { {}, tostring(i), move_to_tag(i) })
  end

  awful.keygrabber({
    root_keybindings = { trigger },
    keybindings = keys,
    stop_key = { "Escape", "Return" },
    stop_callback = function() notify("deactivated") end,
  })
end

do --rules for each client
  local buttons

  local keys = gears.table.join(
    subkey("f", function(c)
      c.fullscreen = not c.fullscreen
      c:raise()
    end),
    subkey("q", function(c) c:kill() end),
    subkey("'", awful.client.floating.toggle),
    subkey("z", function(c) c.minimized = true end),
    nil --
  )

  --Rules to apply to new clients (through the "manage" signal).
  --available props: https://awesomewm.org/doc/api/libraries/awful.rules.html
  awful.rules.rules = {
    { -- All clients will match this rule.
      rule = {},
      properties = {
        --decorations/padding/gap
        honor_workarea = false,
        honor_padding = false,
        size_hints_honor = false,
        titlebar_enabled = false,
        border_width = 1,
        border_color = beautiful.border_normal,
        --

        focus = awful.client.focus.filter,
        raise = false,
        keys = keys,
        buttons = buttons,
        screen = awful.screen.preferred,
        -- placement = awful.placement.no_overlap + awful.placement.no_offscreen,
      },
    },

    {
      rule_any = { class = { "Sxiv" } },
      properties = { floating = true },
    },

    { --note: when there are multiple classes, first is 'rule.instance', second is 'rule.class'
      rule = { instance = "mpv-grid" },
      properties = { screen = 1, tag = "1", floating = false, raise = false, focus = function() return end },
    },
    {
      rule = { instance = "clouds" },
      properties = { floating = true },
    },
    { --weird: one rule for firefox only effects to the first firefox window
      rule_any = {
        class = { "Vivaldi-stable", "firefox" },
        instance = { "vivaldi-stable", "Navigator" },
      },
      properties = { screen = 1, tag = "3", floating = false },
    },
  }
end

do --signals
  awesome.connect_signal("startup", function()
    awful.screen.focus(1)
    capi.screen[1].tags[3].selected = true
  end)

  --when a new client appears.
  capi.client.connect_signal("manage", function(c)
    if not capi.awesome.startup then return end
    -- Prevent clients from being unreachable after screen count changes.
    awful.placement.no_offscreen(c)
  end)

  capi.client.connect_signal("mouse::enter", function(c) c:emit_signal("request::activate", "mouse_enter", { raise = false }) end)
  capi.client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
  capi.client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
end

(function() --autostart
  local is_fresh_start
  do --inspired by https://www.reddit.com/r/awesomewm/comments/cimraw/comment/ev99v9x/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button
    local flag = "awesome_fresh_start"
    capi.awesome.register_xproperty(flag, "boolean")

    function is_fresh_start()
      local fresh = capi.awesome.get_xproperty(flag) == nil
      if fresh then capi.awesome.set_xproperty(flag, false) end
      return fresh
    end
  end

  if not is_fresh_start() then return end

  rclocal.autostart(facts)
end)()
