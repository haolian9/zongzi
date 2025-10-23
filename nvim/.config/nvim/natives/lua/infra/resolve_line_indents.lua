local ctx = require("infra.ctx")
local prefer = require("infra.prefer")

---@param bufnr number
---@param lnum number 0-based line number
---@return string @indents
---@return string @indent char
---@return integer @indent times
return function(bufnr, lnum)
  local nsp = ctx.buf(bufnr, function() return vim.fn.indent(lnum + 1) end)

  local bo = prefer.buf(bufnr)
  if bo.expandtab then
    local ts = bo.tabstop
    return string.rep(" ", nsp), " ", ts
  else
    local ts = bo.tabstop
    return string.rep("\t", nsp / ts), "\t", 1
  end
end
