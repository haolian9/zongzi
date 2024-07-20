local fn = require("infra.fn")
local fs = require("infra.fs")
local bufmap = require("infra.keymap.buffer")
local logging = require("infra.logging")
local strlib = require("infra.strlib")

local batteries = require("batteries")
local defaults = require("langserspecs.defaults")

---see: https://luals.github.io/wiki/settings
---@param powersave boolean
---@return table
local function langserver_config(powersave)
  local uc = vim.fn.stdpath("config")
  assert(type(uc) == "string")

  return {
    runtime = { version = "LuaJIT", pathStrict = true, special = { ["jelly.fatal"] = "error" } },
    diagnostics = {
      enable = true,
      globals = { "vim", "vifm", "mp" },
      -- see: https://luals.github.io/wiki/diagnostics/
      disable = {
        -- for unknown reason, these "duplicate" errors found me
        "duplicate-doc-alias",
        "duplicate-doc-field",
        "duplicate-set-field",
      },
      neededFileStatus = fn.either(powersave, "Opened!", nil),
      severity = fn.either(powersave, "Error", nil),
      workspaceDelay = fn.either(powersave, -1, nil),
      workspaceEvent = fn.either(powersave, "None", nil),
    },
    completion = {
      enable = true,
      autoRequire = false,
      callSnippet = "Both",
      keywordSnippet = "Both", -- ; both keyword and syntax
      displayContext = 1,
      showParams = true,
      showWord = "Disable",
      workspaceWord = false,
    },
    workspace = {
      maxPreload = 0,
      checkThirdParty = "Disable",
      ignoreSubmodules = true,
      library = {
        fs.joinpath(uc, "natives/lua"),
        fs.joinpath(uc, "cthulhu/lua/cthulhu"),
        fs.joinpath(uc, "hybrids/cricket/lua"),
        fs.joinpath(uc, "hybrids/beckon/lua"),
        -- fs.joinpath(uc, "hybrids/guwen/lua"),
        -- fs.joinpath(uc, "hybrids/sh/lua"),

        batteries.datadir("emmylua-stubs/nvim"),
        -- batteries.datadir("emmylua-stubs/vifm"),
        -- "/usr/share/awesome/lib",

        -- "/srv/playground/emmylua-stubs/nvim",
        -- "/srv/playground/emmylua-stubs/vifm",
        -- "/srv/playground/emmylua-stubs/mpv",
        -- "/srv/playground/emmylua-stubs/awesomewm",
      },
    },
    semantic = { enable = false },
    hint = { enable = true }, --[inlay hint](https://luals.github.io/wiki/settings/#hint)
    telemetry = { enable = false },
    format = { enable = false },
  }
end

---@param client vim.lsp.Client
---@param bufnr integer
local function on_attach(client, bufnr)
  defaults.on_attach(client, bufnr)

  local bm = bufmap.wraps(bufnr)
  bm.i(":", ":<c-x><c-o>")
end

---@return vim.lsp.ClientConfig
return function(powersave)
  return {
    name = "luals",
    cmd = { "lua-language-server", "--logpath=" .. logging.newdir("luals") },
    capabilities = defaults.client_caps,
    settings = { Lua = langserver_config(powersave) },
    handlers = {
      ["window/showMessageRequest"] = function(_, result)
        -- no preloading, thanks
        if strlib.startswith(result.message, "Preloaded files has reached the upper limit") then return 0 end
        return vim.lsp.handlers["window/showMessageRequest"](_, result)
      end,
    },
    on_attach = on_attach,
  }
end
