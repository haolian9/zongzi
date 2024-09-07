local M = {}

local resolve_plugin_root = require("infra.resolve_plugin_root")

M.excmd_fpath = string.format("%s/%s", resolve_plugin_root("sh", "facts.lua"), "lua/sh/excmds")

return M
