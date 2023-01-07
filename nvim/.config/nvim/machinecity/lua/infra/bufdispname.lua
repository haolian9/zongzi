local M = {}

local api = vim.api

---@alias infra.bufdispname.resolver fun(bufnr: number, bufname: string): string?

-- protocol-like bufname used by plugins:
-- * term://
-- * fugitive://
-- * man://
-- * kite://
-- * pstree://
-- * nag://
---@param bufname string
---@return number|false
function M.is_protocol(bufname)
  local pos = string.find(bufname, "://")
  return pos ~= nil and pos or false
end

---@type infra.bufdispname.resolver
function M.blank(bufnr, bufname)
  local _ = bufnr
  if bufname ~= "" then return end

  -- todo: name based on buftype, filetype
  return string.format("[unnamed#%d]", bufnr)
end

function M.filetype_abbr(bufnr, bufname)
  local ft = api.nvim_buf_get_option(bufnr, "filetype")
  if ft == "qf" then return "quickfix" end
  if ft == "help" then return "help://" .. vim.fn.fnamemodify(bufname, ":t:r") end
  if ft == "git" then return "git" end
  if ft == "GV" then return "gv" end
  if ft == "checkhealth" then return "checkhealth" end
end

---@type infra.bufdispname.resolver
function M.proto(bufnr, bufname)
  local _ = bufnr
  if not M.is_protocol(bufname) then return end
  return bufname
end

---@type infra.bufdispname.resolver
function M.proto_abbr(bufnr, bufname)
  local _ = bufnr
  local pos = M.is_protocol(bufname)
  if not pos then return end
  return string.sub(bufname, 1, pos - 1)
end

---@return string
function M.relative_stem(bufnr, bufname)
  local _ = bufnr
  return vim.fn.fnamemodify(bufname, ":.:r")
end

---@return string
function M.stem(bufnr, bufname)
  local _ = bufnr
  return vim.fn.fnamemodify(bufname, ":t:r")
end

---@type infra.bufdispname.resolver
function M.blank_abbr(bufnr) end

return M
