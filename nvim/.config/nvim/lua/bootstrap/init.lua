local mi = require("infra.mi")

local profiles = require("profiles")

local here = string.format("%s/lua/bootstrap", mi.stdpath("config"))

-- no module cache for boostrap.{name}
local function fire(name)
  local path = string.format("%s/%s.lua", here, name)
  local chunk = loadfile(path)
  assert(chunk)()
end

---conditional fire
local function cond_fire(name)
  if not profiles.has(name) then return end
  fire(name)
end

do -- main
  fire("monkeypatch")

  require("infra.wincursor").init()
  require("infra.bags").init()

  fire("filetype")
  fire("vim")

  fire("dig")
  cond_fire("lsp")
  fire("langs")

  fire("hal")
  cond_fire("halhacks")

  cond_fire("joy")
end
