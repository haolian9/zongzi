local prefer = require("infra.prefer")

local api = vim.api

---@param bufnr number
---@param lnum number 0-based line number
---@return string,string,number @indents,ichar,iunit
return function(bufnr, lnum)
  local nsp = api.nvim_buf_call(bufnr, function() return vim.fn.indent(lnum + 1) end)

  local bo = prefer.buf(bufnr)
  if bo.expandtab then
    local ts = bo.tabstop
    return string.rep(" ", nsp), " ", ts
  else
    local ts = bo.tabstop
    return string.rep("\t", nsp / ts), "\t", 1
  end
end
