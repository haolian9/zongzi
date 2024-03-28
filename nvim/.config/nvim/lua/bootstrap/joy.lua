local cmds = require("infra.cmds")

local batteries = require("batteries")

if batteries.has("guwen") then
  do --:Guwen
    local comp = cmds.ArgComp.constant(function() return require("guwen").comp.available_sources() end)

    local spell = cmds.Spell("Guwen", function(args) require("guwen")[args.op]() end)
    spell:add_arg("op", "string", true, nil, comp)
    cmds.cast(spell)
  end
end

if batteries.has("cricket") then
  do --:Cricket
    local comp = cmds.ArgComp.constant({ "ctl", "hud", "quit" })
    local spell = cmds.Spell("Cricket", function(args)
      if args.op == "ctl" then
        require("cricket.ui.ctl")()
      elseif args.op == "hud" then
        require("cricket.ui.hud").transient()
      elseif args.op == "quit" then
        require("cricket.player").quit()
      else
        error("unreachable")
      end
    end)
    spell:add_arg("op", "string", false, "ctl", comp)
    cmds.cast(spell)
  end
end
