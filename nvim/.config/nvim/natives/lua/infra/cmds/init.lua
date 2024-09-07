local M = {}

local ni = require("infra.ni")

do --M.create
  local default_attrs = { nargs = 0 }

  ---@param name string
  ---@param handler fun(args: infra.cmds.Args)|string
  ---@param attrs? infra.cmds.Attrs
  function M.create(name, handler, attrs)
    attrs = attrs or default_attrs
    ni.create_user_command(name, handler, attrs)
  end
end

M.ArgComp = require("infra.cmds.ArgComp")
M.Spell = require("infra.cmds.Spell")
M.FlagComp = require("infra.cmds.FlagComp")
M.cast = require("infra.cmds.cast")

return M
