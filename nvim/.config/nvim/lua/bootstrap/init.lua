local profiles = require("profiles")

local api = vim.api

local here = string.format("%s/lua/bootstrap", vim.fn.stdpath("config"))

-- no module cache for boostrap.{name}
local function fire(name)
  local path = string.format("%s/%s.lua", here, name)
  local chunk = loadfile(path)
  assert(chunk)()
end

do -- main
  fire("monkeypatch")

  require("infra.prefer").monkeypatch()

  fire("vim")
  fire("langspecs")
  fire("hal")

  if profiles.has("code") then fire("code") end
  if profiles.has("lsp") then fire("lsp") end
  if profiles.has("joy") then fire("joy") end

  api.nvim_exec_autocmds("user", { pattern = "bootstrapped" })
end
