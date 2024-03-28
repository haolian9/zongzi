local m = require("infra.keymap.global")

local lsp = vim.lsp
local dig = vim.diagnostic

do -- main
  do
    require("optilsp.origins").init()
    require("optilsp.pump").init()
    require("optilsp.snip").init()
  end

  -- builtin lsp, diagnostic
  do
    function dig.setloclist(opts) return require("optilsp.dig_setloclist")(opts) end

    -- i dont need diagnostics.handlers.{signs,underline}, and the latter will even create hi DiagnosticUnnecessary
    dig.config({ signs = false, underline = false, virtual_text = true })

    lsp.handlers["textDocument/signatureHelp"] = function(...) return require("optilsp.hdr_sign")(...) end
    lsp.handlers["textDocument/hover"] = function(...) return require("optilsp.hdr_hover")(...) end
    lsp.util.text_document_completion_list_to_complete_items = function() error("not supposed to call") end
    lsp.util.open_floating_preview = function(...) return require("optilsp.open_floatwin")(...) end
  end

  -- stylua: ignore
  do --diagnostic relevant global keymaps
    m.n("gw", dig.open_float)
    m.n("[w", dig.goto_prev)
    m.n("]w", dig.goto_next)
    --synchronize info of warning and other levels from vim.diagnostic to loclist
    m.n("gsw", dig.setloclist)
    --go to next/prev ERROR diagnostic
    m.n("[e",  function() dig.goto_prev({ severity = dig.severity.ERROR }) end)
    m.n("]e",  function() dig.goto_next({ severity = dig.severity.ERROR }) end)
  end
end
