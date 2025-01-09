local cmds = require("infra.cmds")
local jelly = require("infra.jellyfish")("bootstrap.lsp", "debug")
local m = require("infra.keymap.global")
local repeats = require("infra.repeats")

local lsp = vim.lsp
local dig = vim.diagnostic
local ni = require("infra.ni")

do
  require("optilsp.monkeypatch").init()
  require("optilsp.pump").init()
  require("optilsp.snip").init()
  require("optilsp.procs").init()
end

do -- builtin lsp, diagnostic
  lsp.log.set_level("warn")

  dig.config({
    virtual_text = { source = false, prefix = "✗" },
    ---opt-out: no diagnostics.handlers.{signs,underline}, neither DiagnosticUnnecessary
    signs = false,
    underline = false,
    update_in_insert = false,
    severity_sort = true,
  })
end

do --diagnostic relevant global keymaps
  m.n("gw", dig.open_float)

  ---populate digs into loclist
  m.n("gsw", dig.setloclist)

  ---@param meth 'goto_prev'|'goto_next'
  local function rhs_warn(meth)
    return function()
      dig[meth]()
      repeats.remember_paren(dig.goto_next, dig.goto_prev)
    end
  end
  m.n("[w", rhs_warn("goto_prev"))
  m.n("]w", rhs_warn("goto_next"))

  ---@param meth 'goto_prev'|'goto_next'
  local function rhs_error(meth)
    return function()
      dig[meth]({ severity = dig.severity.ERROR })
      repeats.remember_paren(function() dig.goto_next({ severity = dig.severity.ERROR }) end, function() dig.goto_prev({ severity = dig.severity.ERROR }) end)
    end
  end
  m.n("[e", rhs_error("goto_prev"))
  m.n("]e", rhs_error("goto_next"))
end

do --:Dig, :Lsproc
  cmds.create("Dig", function()
    local bufnr = ni.get_current_buf()
    local toggle = not dig.is_enabled({ bufnr = bufnr })
    jelly.info("toggle lsp.diagnostic buf#%d on=%s", bufnr, toggle)
    --todo: disable it on the server side too
    dig.enable(toggle, { bufnr = bufnr })
  end)

  do
    local spell = cmds.Spell("Lsproc", function(args)
      local procs = require("optilsp.procs")
      if args.op == "expires" then
        procs.expires(args["idle-time"])
      else
        assert(procs[args.op])()
      end
    end)
    spell:add_arg("op", "string", false, "all", cmds.ArgComp.constant({ "all", "idles", "expires", "restart" }))
    spell:add_flag("idle-time", "number", false, 60 * 3)
    cmds.cast(spell)
  end
end
