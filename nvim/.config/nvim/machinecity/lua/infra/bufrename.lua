local unsafe = require("infra.unsafe")
local jelly = require("infra.jellyfish")("infra.bufrename")

local api = vim.api

---@param bufnr number
---@param full_name string @absolute path for buffer
---@param short_name string|nil @when nil then take from full_name
---@return boolean
return function(bufnr, full_name, short_name)
  bufnr = bufnr or api.nvim_get_current_buf()
  assert(full_name ~= nil)

  local ok = unsafe.setfname(bufnr, full_name, short_name)
  if ok then
    unsafe.unchanged(bufnr, false, true)
  else
    jelly.err("failed to rename %d to %s", bufnr, full_name)
  end

  return ok
end
