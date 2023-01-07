local unsafe = require("infra.unsafe")
local jelly = require("infra.jellyfish")("scratch.windim")

local api = vim.api

local ns = api.nvim_create_namespace("scratch.windim")

local state = {
  dimmed_bufnr = nil,
}

return function(raw_win_id, winnr)
  local win_id, bufnr
  do
    if win_id ~= nil then
      win_id = raw_win_id
    elseif winnr ~= nil then
      win_id = vim.fn.win_getid(winnr)
    else
      win_id = api.nvim_get_current_win()
    end
    bufnr = api.nvim_win_get_buf(win_id)
    assert(bufnr ~= 0, "not a valid win_id or winnr")
  end

  if state.dimmed_bufnr ~= nil then api.nvim_buf_clear_namespace(state.dimmed_bufnr, ns, 0, -1) end
  state.dimmed_bufnr = bufnr

  -- 0-based
  local l0, l9
  api.nvim_win_call(win_id, function()
    l0 = vim.fn.line("w0") - 1
    l9 = vim.fn.line("w$") - 1
  end)

  local llens
  do
    local lnums = {}
    for l = l0, l9 do
      lnums[l] = l
    end
    llens = unsafe.lineslen(bufnr, lnums)
  end

  for l = l0, l9 do
    local c0 = 0
    local c9 = llens[l]
    if c9 > 0 then
      local ok, err = pcall(api.nvim_buf_set_extmark, bufnr, ns, l, c0, {
        end_row = l,
        end_col = c9,
        hl_group = "Comment",
      })
      if not ok then jelly.err("%s, (%d, %d~%d)", err, l, c0, c9) end
    end
  end
end
