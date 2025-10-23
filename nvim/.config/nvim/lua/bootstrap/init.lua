local mi = require("infra.mi")
local ni = require("infra.ni")

local profiles = require("profiles")

local here = string.format("%s/lua/bootstrap", mi.stdpath("config"))

-- no module cache for boostrap.{name}
local function fire(name)
  local path = string.format("%s/%s.lua", here, name)
  local chunk = loadfile(path)
  assert(chunk)()
end

do -- main
  fire("monkeypatch")

  require("infra.prefer").monkeypatch()
  require("infra.wincursor").init()

  fire("filetype")
  fire("vim")
  fire("langspecs")
  fire("hal")

  if profiles.has("halhacks") then fire("halhacks") end
  if profiles.has("lsp") then fire("lsp") end
  if profiles.has("joy") then fire("joy") end

  ni.exec_autocmds("user", { pattern = "bootstrapped" })
end
