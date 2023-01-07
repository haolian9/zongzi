local M = {}

local api = vim.api

local profiles = require("profiles")
local lspconfig = require("lspconfig")
local logging = require("infra.logging")
local fs = require("infra.fs")
local lsphandlers = require("optilsp.handlers")
local lsppreviewer = require("optilsp.previewer")
local nvimkeys = require("infra.nvimkeys")

local function buf_keymap(bufnr, mode, lhs, rhs)
  if type(rhs) == "string" then
    vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, { noremap = true, silent = false })
  elseif type(rhs) == "function" then
    vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, "", { noremap = true, silent = false, callback = rhs })
  else
    error(string.format("unsupported rhs: %s", rhs))
  end
end

local rhs_confident_completion = (function()
  local function fire_and_forget()
    local total_compitems = vim.v.event.size
    -- insert the only compitem
    if total_compitems == 1 then api.nvim_feedkeys(nvimkeys("<cr>"), "ni", false) end
  end

  return function()
    -- if pum is started, behave as <c-m>
    if vim.fn.pumvisible() == 1 then return api.nvim_feedkeys(nvimkeys("<cr>"), "ni", false) end

    -- otherwise, behave as <c-n>
    api.nvim_feedkeys(nvimkeys("<c-x><c-o>"), "ni", false)
    -- oneshot callback to emulate `completeopt=menu,insert`
    api.nvim_create_autocmd("CompleteChanged", { once = true, callback = fire_and_forget })
  end
end)()

local function common_buf_keymap(bufnr)
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  buf_keymap(bufnr, "i", "<C-n>", "<C-x><C-o>")
  buf_keymap(bufnr, "i", ".", [[.<c-x><c-o>]])
  buf_keymap(bufnr, "i", "<c-j>", rhs_confident_completion)
  buf_keymap(bufnr, "n", "gd", lsphandlers.rhs_gd)
  buf_keymap(bufnr, "n", "<C-]>", lsphandlers.rhs_gd_vs)
  buf_keymap(bufnr, "n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>")
  buf_keymap(bufnr, "n", "gk", "<cmd>lua vim.lsp.buf.signature_help()<CR>")
  buf_keymap(bufnr, "i", "<c-k>", "<cmd>lua vim.lsp.buf.signature_help()<CR>")
  buf_keymap(bufnr, "n", "gr", "<cmd>lua vim.lsp.buf.rename()<CR>")
  buf_keymap(bufnr, "n", "gu", "<cmd>lua vim.lsp.buf.references()<CR>")
  buf_keymap(bufnr, "n", "ga", "<cmd>lua vim.lsp.buf.code_action()<CR>")
  buf_keymap(bufnr, "n", "gO", "<cmd>lua vim.lsp.buf.document_symbol()<CR>")
  buf_keymap(bufnr, "n", "gD", "<Cmd>lua vim.lsp.buf.type_definition()<CR>")
end

local function common_buf_option(bufnr)
  local bo = vim.bo[bufnr]

  bo.omnifunc = [[v:lua.require'optilsp.omnifunc']]

  -- revert lsp.client.set_default
  for _, name in ipairs({ "tagfunc", "formatexpr" }) do
    if vim.startswith(bo[name], "v:lua.vim.lsp.") then bo[name] = "" end
  end
end

local function default_on_attach(_, bufnr)
  common_buf_option(bufnr)
  common_buf_keymap(bufnr)
end

local nop_diagnostic = {
  -- :h vim.lsp.diagnostic.on_publish_diagnostics()
  ["textDocument/publishDiagnostics"] = function(...) end,
}

local function cold_langservers()
  if profiles.has("php") then
    -- stylua: ignore
    lspconfig["phpactor"].setup({
      on_attach = default_on_attach,
      --handlers = nop_diagnostic
    })
  end

  if profiles.has("nim") then
    lspconfig["nimls"].setup({
      on_attach = default_on_attach,
      -- handlers = nop_diagnostic,
    })
  end

  if profiles.has("ansible") then
    lspconfig["ansiblels"].setup({
      on_attach = default_on_attach,
      -- handlers = nop_diagnostic,
    })
  end

  if profiles.has("rust") then
    lspconfig["rust_analyzer"].setup({
      settings = {
        ["rust-analyzer"] = {
          assist = {
            importGranularity = "module",
            importPrefix = "by_self",
          },
          cargo = {
            loadOutDirsFromCheck = true,
          },
          procMacro = {
            enable = true,
          },
        },
      },
      on_attach = default_on_attach,
      -- handlers = nop_diagnostic,
    })
  end

  if profiles.has("go") then
    lspconfig["gopls"].setup({
      cmd = { "gopls", "serve" },
      settings = {
        gopls = {
          analyses = {
            unusedparams = true,
          },
          staticcheck = true,
        },
      },
      on_attach = default_on_attach,
      -- handlers = nop_diagnostic,
    })
  end

  if profiles.has("fennel") then
    require("lspconfig.configs")["fennel-ls"] = {
      default_config = {
        cmd = { "fennel-ls" },
        filetypes = { "fennel" },
        root_dir = function(dir)
          return lspconfig.util.find_git_ancestor(dir)
        end,
        settings = {},
      },
    }
    lspconfig["fennel-ls"].setup({
      auto_start = true,
      on_attach = function(_, bufnr)
        common_buf_option(bufnr)
        buf_keymap(bufnr, "i", "<C-n>", "<C-x><C-o>")
        buf_keymap(bufnr, "i", ".", [[.<c-x><c-o>]])
        buf_keymap(bufnr, "i", "<c-j>", rhs_confident_completion)
        buf_keymap(bufnr, "n", "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>")
        buf_keymap(bufnr, "n", "<C-]>", lsphandlers.rhs_gd_vs)
      end,
    })
  end
end

local function most_beloved_langservers()
  if profiles.has("python") then
    if profiles.has("python.jedi") then
      -- stylua: ignore
      lspconfig["jedi_language_server"].setup({
        cmd = {
          "jedi-language-server",
          "--log-file", logging.newfile("jedi"),
        },
        on_attach = default_on_attach,
        handlers = nop_diagnostic,
      })
    else
      lspconfig["pyright"].setup({
        on_attach = default_on_attach,
        --handlers = nop_diagnostic,
      })
    end
  end

  if profiles.has("zig") then
    lspconfig["zls"].setup({
      on_attach = function(_, bufnr)
        default_on_attach(_, bufnr)
        -- zls always crashes on renaming
        api.nvim_buf_del_keymap(bufnr, "n", "gr")
      end,
      -- handlers = nop_diagnostic,
    })
  end

  if profiles.has("lua") then
    lspconfig["sumneko_lua"].setup({
      cmd = { "lua-language-server", "--logpath=" .. logging.newdir("sumkeko") },
      auto_start = true,
      on_new_config = function(config, root)
        local _ = root
        local orig = vim.lsp.handlers["window/showMessageRequest"]
        config.handlers["window/showMessageRequest"] = function(_, result)
          if not vim.startswith(result.message, "Preloaded files has reached the upper limit") then
            return orig()
          else
            -- no preloading, thanks
            return 0
          end
        end
      end,
      settings = {
        Lua = {
          runtime = { version = "LuaJIT", fileEncoding = { "utf8" }, builtin = "enable" },
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
          },
          completion = {
            enable = true,
            autoRequire = false,
            -- sumneko.snippet is not compatible with Ultisnips
            callSnippet = "Disable",
            keywordSnippet = "Disable",
            workspaceWord = false,
            showWord = "Disable",
            showParams = false,
          },
          workspace = {
            maxPreload = 0,
            checkThirdParty = false,
            library = (function()
              local uc = vim.fn.stdpath("config")
              local pm = fs.joinpath(vim.fn.stdpath("data"), "plugged")
              return {
                fs.joinpath(uc, "machinecity/lua"),
                fs.joinpath(pm, "emmylua-stubs/nvim"),
                --fs.joinpath(pm, "emmylua-stubs/vifm"),
                --fs.joinpath(pm, "emmylua-stubs/mpv"),
              }
            end)(),
          },
          semantic = { enable = false },
          hint = { enable = false },
          telemetry = { enable = false },
          format = { enable = false },
        },
      },
      on_attach = default_on_attach,
      --handlers = nop_diagnostic,
    })
  end

  if profiles.has("bash") then
    --
    lspconfig["bashls"].setup({
      on_attach = default_on_attach,
    })
  end

  if profiles.has("clang") then
    lspconfig["clangd"].setup({
      autostart = true,
      on_attach = default_on_attach,
      -- handlers = nop_diagnostic,
    })
  end
end

function M.setup()
  cold_langservers()
  most_beloved_langservers()

  -- builtin lsp, diagnostic
  do
    vim.diagnostic.config({ underline = true, virtual_text = true })

    vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(lsphandlers.sign_help, {
      close_events = { "InsertLeave" },
    })

    vim.lsp.handlers["textDocument/hover"] = lsphandlers.hover

    vim.lsp.util.text_document_completion_list_to_complete_items = function()
      error("not supposed to call")
    end

    -- no, i dont need fancy highlights
    vim.lsp.util.open_floating_preview = (function()
      local orig = vim.lsp.util.open_floating_preview
      return function(contents, syntax, opts)
        syntax = nil
        opts = opts or {}
        opts.stylize_markdown = false
        opts.border = "none"
        return orig(contents, syntax, opts)
      end
    end)()
  end

  --- diagnostic relevant global keymaps
  do
    local function keymap(mode, lhs, rhs)
      api.nvim_set_keymap(mode, lhs, rhs, { silent = false, noremap = true })
    end
    keymap("n", "gw", "<cmd>lua vim.diagnostic.open_float()<CR>")
    keymap("n", "[w", "<cmd>lua vim.diagnostic.goto_prev()<CR>")
    keymap("n", "]w", "<cmd>lua vim.diagnostic.goto_next()<CR>")
    -- synchronize info of warning and other levels from vim.diagnostic to loclist
    keymap("n", "gsw", "<cmd>lua vim.diagnostic.setloclist()<CR>")
    -- go to next/prev ERROR diagnostic
    keymap("n", "[e", "<cmd>lua vim.diagnostic.goto_prev({severity = vim.diagnostic.severity.ERROR})<CR>")
    keymap("n", "]e", "<cmd>lua vim.diagnostic.goto_next({severity = vim.diagnostic.severity.ERROR})<CR>")
  end

  lsppreviewer.setup()
end

return M
