local M = {}

local lsp = vim.lsp

for _, tip in ipairs({ "signatureHelp", "hover", "definition", "typeDefinition", "declaration", "implementation" }) do
  local meth = string.format("textDocument/%s", tip)
  M[meth] = lsp.handlers[meth]
end

M.open_floatwin = lsp.util.open_floating_preview

function M.init()
  assert(not package.loaded["optilsp.rhs_goto"])
  assert(not package.loaded["optilsp.hdr_hover"])
  assert(not package.loaded["optilsp.hdr_sign"])
  assert(not package.loaded["optilsp.open_floatwin"])
end

return M
