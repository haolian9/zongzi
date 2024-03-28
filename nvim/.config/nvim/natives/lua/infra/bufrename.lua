local jelly = require("infra.jellyfish")("infra.bufrename")
local prefer = require("infra.prefer")
local unsafe = require("infra.unsafe")

local api = vim.api

---@param bufnr number
---@param full_name string @absolute path for buffer
---@param short_name string|nil @when nil then take from full_name
---@return boolean
return function(bufnr, full_name, short_name)
  bufnr = bufnr or api.nvim_get_current_buf()
  assert(full_name ~= nil)

  local bo = prefer.buf(bufnr)
  local modified = bo.modified
  local ok = unsafe.setfname(bufnr, full_name, short_name)
  if ok then
    -- increase the &changedtick
    unsafe.unchanged(bufnr, false, true)
    -- and restore the &modified
    if modified then bo.modified = modified end
  else
    jelly.err("failed to rename %d to %s", bufnr, full_name)
  end

  return ok
end
