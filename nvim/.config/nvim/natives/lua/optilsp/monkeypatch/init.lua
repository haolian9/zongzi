local M = {}

local lsp = vim.lsp
local dig = vim.diagnostic

do
  local origins = {}
  for _, tip in ipairs({ "signatureHelp", "hover", "definition", "typeDefinition", "declaration", "implementation" }) do
    local meth = string.format("textDocument/%s", tip)
    origins[meth] = assert(lsp.handlers[meth])
  end
  origins.open_floatwin = assert(lsp.util.open_floating_preview)
  origins.apply_workspace_edit = assert(lsp.util.apply_workspace_edit)
  origins.filter_complete_items = assert(lsp._completion._lsp_to_complete_items)
  origins.set_defaults = assert(lsp._set_defaults)
  origins.start = assert(lsp.start)

  M.origins = origins
end

local function impl(...)
  local sub = table.concat({ ... }, ".")
  local mod = "optilsp.monkeypatch." .. sub
  return function(...) return require(mod)(...) end
end

function M.init()
  M.init = nil

  lsp._completion._lsp_to_complete_items = impl("comp_items_fuzzymatch")
  lsp.handlers["textDocument/signatureHelp"] = impl("hdr_sign")
  lsp.handlers["textDocument/hover"] = impl("hdr_hover")
  lsp.util.open_floating_preview = impl("open_floatwin")
  lsp.util.apply_workspace_edit = impl("apply_workspace_edit")
  lsp.buf.rename = impl("rename")
  dig.setloclist = impl("dig_setloclist")

  ---no defaults, i'll do it myself in Client.on_attach
  lsp._set_defaults = function() end
  lsp.start = impl("start")
end

return M
