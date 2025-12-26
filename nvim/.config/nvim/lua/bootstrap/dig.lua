local dig = vim.diagnostic
local cmds = require("infra.cmds")
local jelly = require("infra.jellyfish")("hal", "info")
local m = require("infra.keymap.global")
local ni = require("infra.ni")
local repeats = require("infra.repeats")

do
  ---@param opts {namespace: number, winnr: number, open: boolean, title: string, severity: number}
  dig.setloclist = function(opts)
    opts = opts or {}

    local winid
    do -- no more winnr
      if opts.winnr == nil then
        winid = ni.get_current_win()
      else
        winid = vim.fn.win_getid(opts.winnr)
      end
      opts.winnr = winid
    end

    local items
    do
      local bufnr = ni.win_get_buf(winid)
      local diags = dig.get(bufnr, opts)
      items = dig.toqflist(diags)
    end

    do
      local loc = require("sting").location.shelf(winid, "vim.dig")
      loc:reset()
      loc:extend(items)
      loc:feed_vim(true, false)
    end
  end

  dig.config({
    virtual_text = { source = false, prefix = "✗" },
    ---opt-out: no diagnostics.handlers.{signs,underline}, neither DiagnosticUnnecessary
    signs = false,
    underline = false,
    update_in_insert = false,
    severity_sort = true,
  })
end

do --keymaps
  m.n("gw", dig.open_float)

  ---populate digs into loclist
  m.n("gsw", dig.setloclist)

  ---@param fname 'prev'|'next'
  local function rhs_warn(fname)
    local jumps = {
      next = function() dig.jump({ count = 1, float = true }) end,
      prev = function() dig.jump({ count = -1, float = true }) end,
    }
    local jump = assert(jumps[fname])

    return function()
      jump()
      repeats.remember_paren(jumps.next, jumps.prev)
    end
  end
  m.n("[w", rhs_warn("prev"))
  m.n("]w", rhs_warn("next"))

  ---@param fname 'prev'|'next'
  local function rhs_error(fname)
    local jumps = {
      next = function() dig.jump({ count = 1, float = true, severity = dig.severity.ERROR }) end,
      prev = function() dig.jump({ count = -1, float = true, severity = dig.severity.ERROR }) end,
    }
    local jump = assert(jumps[fname])

    return function()
      jump()
      repeats.remember_paren(jumps.next, jumps.prev)
    end
  end
  m.n("[e", rhs_error("prev"))
  m.n("]e", rhs_error("next"))
end

cmds.create("Dig", function()
  local bufnr = ni.get_current_buf()
  local toggle = not dig.is_enabled({ bufnr = bufnr })
  jelly.info("toggle lsp.diagnostic buf#%d on=%s", bufnr, toggle)
  --concern: disable it on the server side too
  dig.enable(toggle, { bufnr = bufnr })
end)

