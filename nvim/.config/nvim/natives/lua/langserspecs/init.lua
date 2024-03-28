--to disable diagnostic
--* on the server side: textDocument.publishDiagnostics = nil
--* on the client side: handlers['textDocument/publishDiagnostics'] = noop

local Augroup = require("infra.Augroup")
local fs = require("infra.fs")
local bufmap = require("infra.keymap.buffer")
local logging = require("infra.logging")
local nvimkeys = require("infra.nvimkeys")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local api = vim.api

local default_keymaps
do
  local function rhs_comp_first()
    --if pum is started, <c-y>
    if vim.fn.pumvisible() == 1 then return api.nvim_feedkeys(nvimkeys("<c-y>"), "n", false) end

    do --otherwise, behave as <c-n><c-y>
      --necessary workaround
      local aug = Augroup("pum://confident")
      aug:once("CompleteChanged", { once = true, nested = true, callback = function() api.nvim_feedkeys(nvimkeys("<c-y>"), "n", false) end })
      api.nvim_feedkeys(nvimkeys("<c-x><c-o>"), "n", false)
    end
  end

  local function rhs_comp_confirm()
    local key = vim.fn.pumvisible() == 1 and "<c-y>" or "<cr>"
    return api.nvim_feedkeys(nvimkeys(key), "n", false)
  end

  -- stylua: ignore
  --See `:help vim.lsp.*` for documentation on any of the below functions
  function default_keymaps(client, bufnr)
    local bm = bufmap.wraps(bufnr)
    local rhs_goto = require("optilsp.rhs_goto")

    --comp,pum
    bm.i("<c-n>",      "<c-x><c-o>")
    bm.i(".",          ".<c-x><c-o>")
    bm.i("<c-j>",      rhs_comp_first)
    bm.i("<cr>",       rhs_comp_confirm)
    -- --no i_tab here, which is took by parrot

    --other lsp fn
    bm.n("gd",         rhs_goto(client.name, "textDocument/definition"))
    bm.n("<c-w>d",     rhs_goto(client.name, "textDocument/definition", "right"))
    bm.n("<c-]>",      rhs_goto(client.name, "textDocument/typeDefinition"))
    bm.n("<c-w>]",     rhs_goto(client.name, "textDocument/typeDefinition", "right"))
    bm.n("<c-w><c-]>", rhs_goto(client.name, "textDocument/typeDefinition", "right"))
    bm.n("K",          function() vim.lsp.buf.hover() end)
    bm.n("gk",         function() vim.lsp.buf.signature_help() end)
    bm.i("<c-k>",      function() vim.lsp.buf.signature_help() end)
    bm.n("gr",         function() vim.lsp.buf.rename() end)
    bm.n("gu",         function() vim.lsp.buf.references() end)
    bm.n("ga",         function() vim.lsp.buf.code_action() end)
    bm.n("gO",         function() vim.lsp.buf.document_symbol() end)
    bm.n("gD",         function() vim.lsp.buf.type_definition() end)
  end
end

local function default_on_attach(client, bufnr)
  local bo = prefer.buf(bufnr)
  bo.omnifunc = [[v:lua.require'optilsp.omnifunc']]
  for _, name in ipairs({ "formatexpr", "tagfunc" }) do -- revert lsp.client.set_default
    if strlib.startswith(bo[name], "v:lua.vim.lsp.") then bo[name] = "" end
  end

  default_keymaps(client, bufnr)
end

local get_langserspec
do
  local client_caps
  do
    -- see: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification
    local protocol = vim.lsp.protocol
    client_caps = protocol.make_client_capabilities()
    client_caps["textDocument"]["semanticTokens"] = nil
    client_caps["textDocument"]["completion"]["completionItem"]["snippetSupport"] = true
    client_caps["textDocument"]["completion"]["completionItem"]["documentationFormat"] = { protocol.MarkupKind.PlainText }
    client_caps["textDocument"]["hover"]["contentFormat"] = { protocol.MarkupKind.PlainText }
    client_caps["textDocument"]["signatureHelp"]["signatureInformation"]["documentationFormat"] = { protocol.MarkupKind.PlainText }
    client_caps["textDocument"]["signatureHelp"]["signatureInformation"]["documentationFormat"] = { protocol.MarkupKind.PlainText }
    --
    client_caps["workspace"]["semanticTokens"] = nil
    client_caps["workspace"]["didChangeWatchedFiles"] = nil
    --
    client_caps["window"]["workDoneProgress"] = false
    client_caps["window"]["showMessage"] = nil
    client_caps["window"]["showDocument"] = nil
  end

  local client_caps_no_digs
  do
    client_caps_no_digs = vim.deepcopy(client_caps)
    client_caps_no_digs["textDocument"]["publishDiagnostics"] = nil
  end

  ---stole from lspconfig/server_configurations/*
  ---@type {[string]: fun(powersave: boolean):vim.lsp.LangserSpec}
  local defines = {}

  function defines.pyright(powersave)
    local dig_mode = powersave and "openfilesonly" or "workspace"
    return {
      name = "pyright",
      -- see: https://github.com/microsoft/pyright/blob/main/docs/command-line.md
      cmd = { "pyright-langserver", "--stdio" },
      capabilities = client_caps,
      settings = {
        python = {
          analysis = { autoSearchPaths = true, useLibraryCodeForTypes = true, diagnosticMode = dig_mode },
        },
      },
      on_attach = default_on_attach,
    }
  end

  function defines.jedi()
    return {
      name = "jedi",
      cmd = { "jedi-language-server", "--log-file", logging.newfile("jedi") },
      capabilities = client_caps_no_digs,
      on_attach = default_on_attach,
    }
  end

  function defines.zls()
    return {
      name = "zls",
      cmd = { "zls" },
      capabilities = client_caps,
      on_attach = default_on_attach,
    }
  end

  ---@return vim.lsp.LangserSpec
  function defines.luals(powersave)
    local uc = vim.fn.stdpath("config")

    local wd, nfs
    if powersave then
      wd = -1 -- disable workspace level diagnostics
      nfs = "Opened" -- only diagnose opened files
    end

    return {
      name = "luals",
      cmd = { "lua-language-server", "--logpath=" .. logging.newdir("sumkeko") },
      capabilities = client_caps,
      settings = {
        Lua = {
          runtime = { version = "LuaJIT", fileEncoding = { "utf8" } },
          diagnostics = {
            enable = true,
            globals = { "vim", "vifm", "mp" },
            -- see: https://github.com/sumneko/lua-language-server/wiki/Diagnostics
            disable = {
              -- for unknown reason, these "duplicate" errors found me
              "duplicate-doc-alias",
              "duplicate-doc-field",
              "duplicate-set-field",
            },
            workspaceDelay = wd,
            neededFileStatus = nfs,
          },
          completion = {
            enable = true,
            autoRequire = false,
            callSnippet = "Both", -- "Disable"|"Both"|"Replace"; both function and call
            keywordSnippet = "Both", -- ; both keyword and syntax
            displayContext = 1,
            showParams = true,
            showWord = "Disable", -- "Enable"|"Fallback"|"Disable"
            workspaceWord = false,
          },
          workspace = {
            maxPreload = 0,
            checkThirdParty = false,
            library = {
              fs.joinpath(uc, "natives/lua"),
              fs.joinpath(uc, "cthulhu/lua/cthulhu"),
              fs.joinpath(uc, "hybrids/cricket/lua"),
              fs.joinpath(uc, "hybrids/guwen/lua"),
              fs.joinpath(uc, "hybrids/sh/lua"),
              batteries.datadir("emmylua-stubs/nvim"),
              batteries.datadir("emmylua-stubs/vifm"),
            },
          },
          semantic = { enable = false },
          hint = { enable = false },
          telemetry = { enable = false },
          format = { enable = false },
        },
      },
      handlers = {
        ["window/showMessageRequest"] = function(_, result)
          -- no preloading, thanks
          if strlib.startswith(result.message, "Preloaded files has reached the upper limit") then return 0 end
          return vim.lsp.handlers["window/showMessageRequest"](_, result)
        end,
      },
      on_attach = default_on_attach,
    }
  end

  function defines.clangd()
    return {
      name = "clangd",
      cmd = { "clangd", "--background-index" },
      capabilities = client_caps_no_digs,
      on_attach = default_on_attach,
    }
  end

  function defines.gopls()
    --todo: avoid diagnose all files in the workspace under powersave mode
    return {
      name = "gopls",
      cmd = { "gopls", "serve" },
      capabilities = client_caps,
      settings = {
        gopls = {
          analyses = { unusedparams = true },
          staticcheck = true,
        },
      },
      on_attach = default_on_attach,
    }
  end

  function defines.nimls()
    return {
      name = "nimls",
      cmd = { "nimlsp" },
      capabilities = client_caps,
      on_attach = default_on_attach,
    }
  end

  function defines.phpactor()
    return {
      name = "phpactor",
      cmd = { "phpactor", "language-server" },
      capabilities = client_caps,
      on_attach = default_on_attach,
    }
  end

  function defines.ansiblels()
    return {
      name = "ansiblels",
      cmd = { "ansible-language-server", "--stdio" },
      capabilities = client_caps,
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
      on_attach = default_on_attach,
    }
  end

  ---@type {[string]: vim.lsp.LangserSpec}
  local evaluated = {}

  ---@param name string
  ---@param powersave boolean
  ---@return vim.lsp.LangserSpec
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
---@return vim.lsp.LangserSpec
return function(name, root_dir, powersave)
  if powersave == nil then powersave = false end
  return setmetatable({ root_dir = root_dir }, get_langserspec(name, powersave))
end
