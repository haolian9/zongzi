local ni = require("infra.ni")
local uv = vim.uv

---assumes it's a lua plugin and with filesystem layout &rtp/lua/{plugin_name}/*.lua
---@param plugin_name string
---@param fname string? @nil=init.lua
---@return string @no trailing slash
return function(plugin_name, fname)
  fname = fname or "init.lua"

  local pattern = string.format("lua/%s/%s", plugin_name, fname)
  local files = ni.get_runtime_file(pattern, false)
  assert(files and #files == 1)

  local luadir = string.sub(files[1], 1, -(#fname + 2))

  local root, err = uv.fs_realpath(luadir .. "/../../")
  if root == nil then error(err) end
  assert(string.sub(root, #root, #root) ~= "/")
  return root
end
