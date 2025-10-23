local M = {}

local ffi = require("ffi")

local resolve_plugin_root = require("infra.resolve_plugin_root")

ffi.cdef([[
  int capsbulb_state();
]])

local C
do
  local path = string.format("%s/zig-out/lib/libcapsbulb.so", resolve_plugin_root("capsbulb", "unsafe.lua"))
  C = ffi.load(path, false)
end

function M.is_capslock_on()
  --todo: it could fail
  return C.capsbulb_state() == 1
end

return M
