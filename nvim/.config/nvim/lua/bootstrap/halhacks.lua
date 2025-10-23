local cmds = require("infra.cmds")
local G = require("infra.G")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("bootstrap.halhacks", "info")

do
  require("msgcleaner").activate()
  require("gary").activate()

  do
    ---@type olds.G
    local g = G("olds")
    g.create_client = function() return require("olds.RedisClient").connect_unix("/run/user/1000/redis.sock") end

    local olds = require("olds")
    olds.start_recording()
  end
end

do --:Olds
  local subcmds = { "start_recording", "stop_recording", "show_history", "prune_history", "reset_history", "ping" }

  local spell = cmds.Spell("Olds", function(args)
    if itertools.contains(subcmds, args.subcmd) then --
      local olds = require("olds")
      return olds[args.subcmd]()
    end
    jelly.warn("no such subcmd for :Olds")
  end)
  spell:add_arg("subcmd", "string", false, "show_history", cmds.ArgComp.constant(subcmds))
  cmds.cast(spell)
end

do --:Gary
  local spell = cmds.Spell("Gary", function(args)
    local gary = require("gary")
    if args.op == "deactivate" then
      gary[args.op]()
    else
      gary.activate(true, args.op)
    end
  end)
  local comp = cmds.ArgComp.constant({ "flat", "colorful", "deactivate" })
  spell:add_arg("op", "string", false, "flat", comp)
  cmds.cast(spell)
end
