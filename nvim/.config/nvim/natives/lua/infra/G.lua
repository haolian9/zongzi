---concerns:
---* default value
---* nested dict
---
---usage
---* on the user side: `local g = require'infra.G'(mod); g.x = y`
---* on the plug/mod side: `mod/g.lua`, `return require'infra.G'(mod)`
---

---@param ns string @namespace: a plugin name
---@return table
return function(ns)
  if _G.g == nil then _G.g = {} end
  if _G.g[ns] == nil then _G.g[ns] = {} end
  return _G.g[ns]
end
