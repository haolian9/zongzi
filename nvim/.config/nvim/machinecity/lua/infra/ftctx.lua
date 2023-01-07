local api = vim.api

local function noremap_wraper(bufnr, mode)
  return function(lhs, rhs, opts)
    opts = opts or {}
    opts.noremap = true
    if type(rhs) == "function" then
      opts.callback = rhs
      rhs = ""
    end
    api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, opts)
  end
end

local function generate_globals()
  local bufnr = api.nvim_get_current_buf()
  local win_id = api.nvim_get_current_win()
  local ex = require("infra.ex")
  return {
    ex = ex,
    go = vim.go,
    bo = vim.bo[bufnr],
    b = vim.b[bufnr],
    -- todo: inject bufnr
    bopt = vim.opt_local,
    wo = vim.wo[win_id],
    nnoremap = noremap_wraper(bufnr, "n"),
    vnoremap = noremap_wraper(bufnr, "v"),
  }
end

return function(inside, did_ftplugin)
  did_ftplugin = did_ftplugin or true
  local globals = generate_globals()
  for k, v in pairs(globals) do
    assert(_G[k] == nil)
    _G[k] = v
  end
  inside()
  for k, _ in pairs(globals) do
    _G[k] = nil
  end
  if did_ftplugin then globals.b.did_ftplugin = 1 end
end
