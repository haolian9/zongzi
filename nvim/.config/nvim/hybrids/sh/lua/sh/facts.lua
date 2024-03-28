local M = {}

local fs = require("infra.fs")

M.excmd_fpath = fs.joinpath(fs.resolve_plugin_root("sh", "facts.lua"), "excmds")

return M
