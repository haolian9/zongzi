local cmds = require("infra.cmds")
local dictlib = require("infra.dictlib")
local fs = require("infra.fs")
local its = require("infra.its")
local logging = require("infra.logging")
local mi = require("infra.mi")
local project = require("infra.project")
local strlib = require("infra.strlib")

local batteries = require("batteries")
local profiles = require("profiles")

local lsp = vim.lsp
local protocol = vim.lsp.protocol

do
  require("optilsp.monkeypatch").init()
  require("optilsp.pump").init()
  require("optilsp.snip").init()
  require("optilsp.procs").init()

  lsp.log.set_level("warn")
end

do --server specs
  local powersave = profiles.has("powersave")
  local uc = mi.stdpath("config")
  local excluded_roots = {
    [assert(vim.env.HOME)] = true,
    ["/srv/playground"] = true,
  }

  local client_caps = {}
  do
    do
      -- see: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification
      local caps = protocol.make_client_capabilities()
      caps.textDocument.semanticTokens = nil
      caps.textDocument.completion.completionItem.snippetSupport = false
      caps.textDocument.completion.completionItem.labelDetailsSupport = true
      caps.textDocument.completion.completionItem.documentationFormat = { protocol.MarkupKind.PlainText }
      --todo: .insertReplaceSupport, deprecatedSupport
      caps.textDocument.hover.contentFormat = { protocol.MarkupKind.PlainText }
      caps.textDocument.signatureHelp.signatureInformation.documentationFormat = { protocol.MarkupKind.PlainText }
      caps.textDocument.signatureHelp.signatureInformation.documentationFormat = { protocol.MarkupKind.PlainText }
      caps.textDocument.inlayHint = nil --todo: server just ignore this, but why?
      --
      caps.workspace.semanticTokens = nil
      caps.workspace.didChangeWatchedFiles = nil
      caps.workspace.inlayHint = nil
      --
      caps.window.workDoneProgress = false
      caps.window.showMessage = nil
      caps.window.showDocument = nil
      --
      client_caps.general = caps
    end

    do
      local caps = vim.deepcopy(client_caps.general)
      caps.textDocument.publishDiagnostics = nil
      --
      client_caps.no_digs = caps
    end

    do
      local caps = vim.deepcopy(client_caps.general)
      dictlib.set(caps, { "general", "positionEncodings" }, { "utf-8" })
      --
      client_caps.utf8 = caps
    end
  end

  ---@return string? @nil=single file mode if the langser supports
  local function resolve_root_dir(bufnr)
    local root
    root = project.git_root(bufnr)
    if root ~= nil then return root end
    root = project.working_root()
    if excluded_roots[root] then return end
    return root
  end

  ---@param client vim.lsp.Client
  ---@param config vim.lsp.ClientConfig
  ---@return boolean
  local function is_reusable(client, config)
    if client.name ~= config.name then return false end
    ---NB: root_dir=nil indicates single file mode
    if config.root_dir == nil then
      return client.root_dir == nil
    else
      if client.root_dir == nil then return false end
      if client.root_dir == config.root_dir then return true end
      return its(client.workspace_folders):project("name"):contains(config.root_dir)
    end
  end

  lsp.config("*", { --
    root_dir = resolve_root_dir,
    reuse_client = is_reusable,
    ---use larger debounce time window, send less didChanged requests, trigger less LspNotify
    ---also do full sync, to avoid wasting cpu on computing diff
    flags = { allow_incremental_sync = true, debounce_text_changes = 850 },
  })

  ---see: https://luals.github.io/wiki/settings
  lsp.config.luals = {
    name = "luals",
    cmd = { "lua-language-server", "--logpath=" .. logging.newdir("luals") },
    capabilities = client_caps.general,
    settings = {
      Lua = {
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
          neededFileStatus = powersave and "Opened!" or nil,
          severity = powersave and "Error" or nil,
          workspaceDelay = powersave and -1 or nil,
          workspaceEvent = powersave and "None" or nil,
        },
        completion = {
          enable = true,
          autoRequire = false,
          callSnippet = "Disable", --Disable|Both|Replace
          keywordSnippet = "Disable",
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
      },
    },
    handlers = {
      ["window/showMessageRequest"] = function(_, result)
        -- no preloading
        if strlib.startswith(result.message, "Preloaded files has reached the upper limit") then return 0 end
        return vim.lsp.handlers["window/showMessageRequest"](_, result)
      end,
    },
  }

  lsp.config.emmyluals = {
    cmd = { "emmylua_ls", "--editor=neovim" },
    capabilities = client_caps.general,
    settings = {},
  }

  lsp.config.pyright = {
    -- see: https://github.com/microsoft/pyright/blob/main/docs/command-line.md
    cmd = { "pyright-langserver", "--stdio" },
    capabilities = client_caps.general,
    settings = {
      python = {
        analysis = {
          autoSearchPaths = true,
          useLibraryCodeForTypes = true,
          diagnosticMode = powersave and "openfilesonly" or "workspace",
        },
      },
    },
  }

  lsp.config.ty = {
    cmd = { "ty", "server" },
    capabilities = client_caps.general,
    settings = { ty = {} },
  }

  lsp.config.jedi = {
    cmd = { "jedi-language-server", "--log-file", logging.newfile("jedi") },
    capabilities = client_caps.no_digs,
  }

  lsp.config.zls = {
    cmd = { "zls" },
    capabilities = client_caps.general,
  }

  lsp.config.clangd = {
    cmd = { "clangd", "--background-index" },
    capabilities = client_caps.no_digs,
  }

  lsp.config.gopls = {
    cmd = { "gopls", "serve" },
    capabilities = client_caps.general,
    settings = {
      gopls = {
        analyses = { unusedparams = true },
        staticcheck = true,
      },
    },
  }

  lsp.config.nimls = {
    cmd = { "nimlsp" },
    capabilities = client_caps.general,
  }

  lsp.config.phpactor = {
    cmd = { "phpactor", "language-server" },
    capabilities = client_caps.general,
  }

  lsp.config.ansiblels = {
    cmd = { "ansible-language-server", "--stdio" },
    capabilities = client_caps.general,
    settings = {
      ansible = {
        python = { interpreterPath = "python" },
        ansible = { path = "ansible" },
        executionEnvironment = { enabled = false },
        validation = {
          enabled = true,
          lint = { enabled = true, path = "ansible-lint" },
        },
      },
    },
  }

  lsp.config.cmakels = {
    cmd = { "neocmakelsp", "--stdio" },
    capabilities = client_caps.no_digs,
    init_options = {
      format = { enable = false },
      scan_cmake_in_package = true,
    },
  }

  lsp.config.vuels = {
    cmd = { "vue-language-server", "--stdio" },
    capabilities = client_caps.no_digs,
  }
end

do --:Dig
  local spell = cmds.Spell("Lsproc", function(args)
    local procs = require("optilsp.procs")
    if args.op == "expires" then
      procs.expires(args["idle-time"])
    else
      assert(procs[args.op])()
    end
  end)
  spell:add_arg("op", "string", false, "all", cmds.ArgComp.constant({ "all", "idles", "expires", "restart", "kill" }))
  spell:add_flag("idle-time", "number", false, 60 * 3)
  cmds.cast(spell)
end
