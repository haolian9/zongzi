--to disable diagnostic
--* on the server side: textDocument.publishDiagnostics = nil
--* on the client side: handlers['textDocument/publishDiagnostics'] = noop

local logging = require("infra.logging")

local defaults = require("langserspecs.defaults")

local get_langserspec
do
  ---stole from lspconfig/server_configurations/*
  ---@type {[string]: fun(powersave: boolean):vim.lsp.ClientConfig}
  local defines = {}

  defines.luals = require("langserspecs.luals")

  function defines.pyright(powersave)
    local dig_mode = powersave and "openfilesonly" or "workspace"
    return {
      name = "pyright",
      -- see: https://github.com/microsoft/pyright/blob/main/docs/command-line.md
      cmd = { "pyright-langserver", "--stdio" },
      capabilities = defaults.client_caps,
      settings = {
        python = {
          analysis = { autoSearchPaths = true, useLibraryCodeForTypes = true, diagnosticMode = dig_mode },
        },
      },
      on_attach = defaults.on_attach,
    }
  end

  function defines.jedi()
    return {
      name = "jedi",
      cmd = { "jedi-language-server", "--log-file", logging.newfile("jedi") },
      capabilities = defaults.client_caps_no_digs,
      on_attach = defaults.on_attach,
    }
  end

  function defines.zls()
    return {
      name = "zls",
      cmd = { "zls" },
      capabilities = defaults.client_caps,
      on_attach = defaults.on_attach,
    }
  end

  function defines.clangd()
    return {
      name = "clangd",
      cmd = { "clangd", "--background-index" },
      capabilities = defaults.client_caps_no_digs,
      on_attach = defaults.on_attach,
    }
  end

  function defines.gopls()
    --todo: avoid diagnose all files in the workspace under powersave mode
    return {
      name = "gopls",
      cmd = { "gopls", "serve" },
      capabilities = defaults.client_caps,
      settings = {
        gopls = {
          analyses = { unusedparams = true },
          staticcheck = true,
        },
      },
      on_attach = defaults.on_attach,
    }
  end

  function defines.nimls()
    return {
      name = "nimls",
      cmd = { "nimlsp" },
      capabilities = defaults.client_caps,
      on_attach = defaults.on_attach,
    }
  end

  function defines.phpactor()
    return {
      name = "phpactor",
      cmd = { "phpactor", "language-server" },
      capabilities = defaults.client_caps,
      on_attach = defaults.on_attach,
    }
  end

  function defines.ansiblels()
    return {
      name = "ansiblels",
      cmd = { "ansible-language-server", "--stdio" },
      capabilities = defaults.client_caps,
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
      on_attach = defaults.on_attach,
    }
  end

  function defines.cmakels()
    return {
      name = "cmakels",
      cmd = { "neocmakelsp", "--stdio" },
      capabilities = defaults.client_caps_no_digs,
      init_options = {
        format = { enable = false },
        scan_cmake_in_package = true,
      },
      on_attach = defaults.on_attach,
    }
  end

  function defines.vuels()
    return {
      name = "vuels",
      cmd = { "vue-language-server", "--stdio" },
      capabilities = defaults.client_caps_no_digs,
      on_attach = defaults.on_attach,
    }
  end

  ---@type {[string]: vim.lsp.ClientConfig}
  local evaluated = {}

  ---@param name string
  ---@param powersave boolean
  function get_langserspec(name, powersave)
    if evaluated[name] == nil then
      local spec = assert(defines[name])(powersave)
      ---@diagnostic disable-next-line: inject-field
      spec.__index = spec
      evaluated[name] = spec
    end
    return evaluated[name]
  end
end

---@param name string
---@param root_dir? string
---@param powersave? boolean @nil=false
---@return vim.lsp.ClientConfig
return function(name, root_dir, powersave)
  if powersave == nil then powersave = false end
  return setmetatable({ root_dir = root_dir }, get_langserspec(name, powersave))
end
