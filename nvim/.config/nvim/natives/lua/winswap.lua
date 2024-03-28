local ctx = require("infra.ctx")
local jelly = require("infra.jellyfish")("winmove", "debug")
local tty = require("infra.tty")

local api = vim.api

---@param winnr integer
local function swap(winnr)
  local src_winid = api.nvim_get_current_win()
  local dest_winid = vim.fn.win_getid(winnr)
  if dest_winid == 0 then return jelly.warn("no such win by nr#%d", winnr) end
  if src_winid == dest_winid then return jelly.info("same win") end

  local src_bufnr = api.nvim_win_get_buf(src_winid)
  local dest_bufnr = api.nvim_win_get_buf(dest_winid)

  ctx.noautocmd("all", function()
    api.nvim_win_set_buf(src_winid, dest_bufnr)
    api.nvim_win_set_buf(dest_winid, src_bufnr)
  end)
end

---@param winnr? integer @when nil, ask one
return function(winnr)
  if winnr == nil then
    local _, code = tty.read_raw()
    --only 1-9
    if not (code >= 49 and code <= 57) then return end
    winnr = tonumber(string.char(code))
  end
  assert(winnr ~= nil and winnr ~= 0)

  return swap(winnr)
end
