local cmds = require("infra.cmds")
local ex = require("infra.ex")
local G = require("infra.G")

local batteries = require("batteries")

local uv = vim.uv

do --:Wiki
  cmds.create("Wiki", function()
    local home = assert(vim.env.HOME)
    ex("tabedit", home .. "/vimwiki/index.wiki")
    ex("tcd", home .. "/vimwiki")
    require("linesexpr.tabline").rename("wiki")
  end)
end

if batteries.has("guwen") then
  do --:Guwen
    local comp = cmds.ArgComp.constant(function() return require("guwen").comp.available_sources() end)

    local spell = cmds.Spell("Guwen", function(args) require("guwen")[args.op]() end)
    spell:add_arg("op", "string", true, nil, comp)
    cmds.cast(spell)
  end
end

if batteries.has("cricket") then
  if false and uv.os_gethostname() == "eugene" then
    ---@type cricket.G
    local g = G("cricket")
    g.init_props = {
      --see `mpv --audio-devices=help`
      ["audio-device"] = "pipewire/alsa_output.usb-Creative_Technology_USB_Sound_Blaster_HD_0000027j-00.analog-stereo",
    }
  end

  do --:Cricket
    local comp = cmds.ArgComp.constant({ "ctl", "hud", "quit", "feed_obs", "audiodevices" })
    local spell = cmds.Spell("Cricket", function(args)
      if args.op == "ctl" then
        require("cricket.ui.ctl").floatwin()
      elseif args.op == "hud" then
        require("cricket.ui.hud")()
      elseif args.op == "quit" then
        require("cricket.player").quit()
      elseif args.op == "feed_obs" then
        require("cricket.obs").feed()
      elseif args.op == "audiodevices" then
        require("cricket.ui.audiodevices").switch()
      else
        error("unreachable")
      end
    end)
    spell:add_arg("op", "string", false, "ctl", comp)
    cmds.cast(spell)
  end
end

do --:BloodMoon
  local spell = cmds.Spell("BloodMoon", function(args) assert(require("bloodmoon")[args.op])() end)
  spell:add_arg("op", "string", false, "show", cmds.ArgComp.constant({ "enable", "disable", "show" }))
  cmds.cast(spell)
end

do --:CapsBulb
  cmds.create("CapsBulb", function() require("capsbulb").toggle_warn() end)
end
