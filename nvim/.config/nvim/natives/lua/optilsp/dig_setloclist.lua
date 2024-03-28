local sting = require("sting")

local api = vim.api
local dig = vim.diagnostic

---@param opts {namespace: number, winnr: number, open: boolean, title: string, severity: number}
return function(opts)
  opts = opts or {}

  local winid
  do -- no more winnr
    if opts.winnr == nil then
      winid = api.nvim_get_current_win()
    else
      winid = vim.fn.win_getid(opts.winnr)
    end
    opts.winnr = winid
  end

  local items
  do
    local bufnr = api.nvim_win_get_buf(winid)
    local diags = dig.get(bufnr, opts)
    items = dig.toqflist(diags)
  end

  do
    local loc = sting.location.shelf(winid, "vim.diagnostic")
    loc:reset()
    loc:extend(items)
    loc:feed_vim(true, false)
  end
end
