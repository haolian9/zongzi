local ni = require("infra.ni")

---assumes it's a lua plugin and with filesystem layout &rtp/lua/{plugin_name}/*.lua
---@param plugin_name string
---@param fname string? @nil=init.lua
---@return string @no trailing slash
return function(plugin_name, fname)
  fname = fname or "init.lua"

  local suffix = string.format("lua/%s/%s", plugin_name, fname)

  local path = ni.get_runtime_file(suffix, false)[1]
  assert(path, "plugin no found")

  return string.sub(path, 1, -(#"/" + #suffix))
end
