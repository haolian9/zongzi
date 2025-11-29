local lsputil = require("vim.lsp.util")

local jelly = require("infra.jellyfish")("optilsp.apply_edits", "debug")

---customize:
---* disallow create/delete change
---
---@param workspace_edit table `WorkspaceEdit`
---@param offset_encoding string utf-8|utf-16|utf-32
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_applyEdit
return function(workspace_edit, offset_encoding)
  if offset_encoding == nil then return jelly.fatal("ValueError", "apply_workspace_edit must be called with valid offset encoding") end

  if workspace_edit.documentChanges then
    for idx, change in ipairs(workspace_edit.documentChanges) do
      if change.kind == "rename" then
        lsputil.rename(vim.uri_to_fname(change.oldUri), vim.uri_to_fname(change.newUri), change.options)
      elseif change.kind == "create" then
        return jelly.fatal("UnsupportedError", "no allowing fs.creation requests; %s", change)
      elseif change.kind == "delete" then
        return jelly.fatal("UnsupportedError", "no allowing fs.deletion requests; %s", change)
      elseif change.kind then
        return jelly.fatal("UnsupportedError", "unknown fs.change requests; %s", change)
      else
        lsputil.apply_text_document_edit(change, idx, offset_encoding)
      end
    end
  elseif workspace_edit.changes then
    local all_changes = workspace_edit.changes
    for uri, changes in pairs(all_changes) do
      local bufnr = vim.uri_to_bufnr(uri)
      lsputil.apply_text_edits(changes, bufnr, offset_encoding)
    end
  else
    return jelly.fatal("TrashResponse", "no-op in workspace_edit resp: %s", workspace_edit)
  end
end
