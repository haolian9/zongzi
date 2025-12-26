local M = {}

local Keyring = require("puff.Keyring")
local Menu = require("puff.Menu")

M.input = require("puff.input")

do
  local key_pool = Keyring("asdfjkl" .. "gh" .. "wertyuiop" .. "zxcvbnm" .. "ASDFJKL" .. "GH" .. "WERTYUIOP" .. "ZXCVBNM")
  local function default_entfmt(ent) return ent end

  ---keep the same signature as vim.ui.select
  ---user should check if entry and index are nil in on_choice()
  ---@param items any[]
  ---@param opts {prompt?:string, format_item?:(fun(item):string), kind?:string}
  ---@param on_choice fun(entry?:string, index?:number) @index: 1-based
  function M.select(items, opts, on_choice)
    assert(#items > 0)
    opts = opts or {}

    local entfmt
    if opts.kind ~= nil then
      entfmt = assert(opts.format_item, "opts.format_item is required for custom opts.kind")
    else
      entfmt = opts.format_item or default_entfmt
    end

    Menu({
      key_pool = key_pool,
      subject = opts.prompt,
      desc = nil,
      entries = items,
      entfmt = entfmt,
      on_decide = on_choice,
      colorful = true,
    })
  end
end

do
  local key_pool = Keyring("yn")
  local entries = { "go ahead", "wait, no" }
  local function entfmt(ent) return ent end

  ---@param opts {subject?:string, desc?:string[], entries?:[string,string]}
  ---@param on_decide fun(confirmed:boolean)
  function M.confirm(opts, on_decide)
    Menu({
      key_pool = key_pool,
      subject = opts.subject,
      desc = opts.desc,
      entries = opts.entries or entries,
      entfmt = entfmt,
      on_decide = function(_, index) on_decide(index == 1) end,
      colorful = true,
    })
  end
end

return M
