local ropes = require("string.buffer")

local excmds = assert(loadfile("/srv/playground/neovim/src/nvim/ex_cmds.lua"))()

local file = assert(io.open("../lua/sh/excmds", "w"))

local rope = ropes.new()
for _, defn in ipairs(excmds.cmds) do
  rope:put(defn.command, "\n")
end

file:write(rope:get())
file:close()
