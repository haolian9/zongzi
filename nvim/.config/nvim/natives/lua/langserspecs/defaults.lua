local M = {}

local augroups = require("infra.augroups")
local dictlib = require("infra.dictlib")
local feedkeys = require("infra.feedkeys")
local bufmap = require("infra.keymap.buffer")
local prefer = require("infra.prefer")

local lsp = vim.lsp
local protocol = vim.lsp.protocol

do
  local function rhs_comp_first()
    --if pum is started, <c-y>
    if vim.fn.pumvisible() == 1 then return feedkeys("<c-y>", "n") end

    do --otherwise, behave as <c-n><c-y>
      --necessary workaround
      local aug = augroups.Augroup("pum://confident")
      --todo: i believe this aucmd does not get triggered properly
      aug:once("CompleteChanged", { nested = true, callback = function() feedkeys("<c-y>", "n") end })
      feedkeys("<c-x><c-o>", "n")
    end
  end

  local function rhs_comp_confirm()
    local key = vim.fn.pumvisible() == 1 and "<c-y>" or "<cr>"
    return feedkeys(key, "n")
  end

  --See `:help vim.lsp.*` for documentation on any of the below functions
  ---@param client vim.lsp.Client
  ---@param bufnr integer
  function M.keymaps(client, bufnr)
    local bm = bufmap.wraps(bufnr)
    local rhs_goto = require("optilsp.rhs_goto")

    --stylua: ignore
    do
      --comp,pum
      bm.i("<c-n>", "<c-x><c-o>")
      bm.i(".",     ".<c-x><c-o>")
      bm.i("<c-j>", rhs_comp_first)
      bm.i("<cr>",  rhs_comp_confirm)
      --no i_tab here, which is took by parrot

      bm.n("gd",         rhs_goto(client.name, "textDocument/definition"))
      bm.n("<c-w>d",     rhs_goto(client.name, "textDocument/definition", "right"))
      bm.n("<c-]>",      rhs_goto(client.name, "textDocument/typeDefinition"))
      bm.n("<c-w>]",     rhs_goto(client.name, "textDocument/typeDefinition", "right"))
      bm.n("<c-w><c-]>", rhs_goto(client.name, "textDocument/typeDefinition", "right"))

      bm.n("K",     function() lsp.buf.hover() end)
      bm.n("gk",    function() lsp.buf.signature_help() end)
      bm.i("<c-k>", function() lsp.buf.signature_help() end)
      bm.n("gr",    function() lsp.buf.rename() end)
      bm.n("gu",    function() lsp.buf.references() end)
      bm.n("ga",    function() lsp.buf.code_action() end)
      bm.n("gO",    function() lsp.buf.document_symbol() end)
      bm.n("gD",    function() lsp.buf.type_definition() end)
    end
  end
end

---@param client vim.lsp.Client
---@param bufnr integer
function M.on_attach(client, bufnr)
  prefer.bo(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")
  if client.supports_method(protocol.Methods.textDocument_diagnostic) then lsp.diagnostic._enable(bufnr) end

  M.keymaps(client, bufnr)
end

do
  local caps
  -- see: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification
  caps = protocol.make_client_capabilities()
  caps.textDocument.semanticTokens = nil
  caps.textDocument.completion.completionItem.snippetSupport = true
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

  M.client_caps = caps
end

do
  local caps
  caps = vim.deepcopy(M.client_caps)
  caps.textDocument.publishDiagnostics = nil

  M.client_caps_no_digs = caps
end

do
  local caps
  caps = vim.deepcopy(M.client_caps)
  dictlib.set(caps, { "general", "positionEncodings" }, { "utf-8" })

  M.client_caps_utf8 = caps
end

return M
