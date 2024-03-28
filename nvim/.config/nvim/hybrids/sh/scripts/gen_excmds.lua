local excmds = assert(loadfile("/srv/playground/neovim/src/nvim/ex_cmds.lua"))()

local file = assert(io.open("../lua/sh/excmds", "w"))

local cmds = {}
for _, defn in ipairs(excmds.cmds) do
  table.insert(cmds, assert(defn.command))
end

file:write(table.concat(cmds, "\n"))
file:write("\n")
file:close()
