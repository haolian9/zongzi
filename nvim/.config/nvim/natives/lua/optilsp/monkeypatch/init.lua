local M = {}

local lsp = vim.lsp

do
  local origins = {}
  origins.apply_workspace_edit = assert(lsp.util.apply_workspace_edit)
  M.origins = origins
end

local function impl(...)
  local sub = table.concat({ ... }, ".")
  local mod = "optilsp.monkeypatch." .. sub
  return function(...) return require(mod)(...) end
end

function M.init()
  M.init = nil

  lsp.completion._lsp_to_complete_items = impl("comp_items_fuzzymatch")
  lsp.util.apply_workspace_edit = impl("apply_workspace_edit")

  ---no defaults, i'll do it myself
  lsp._set_defaults = function() end
end

return M
