local M = {}

local fs = require("infra.fs")
local ni = require("infra.ni")
local prefer = require("infra.prefer")

---based on buftype and bufname
---@param bufnr integer
---@param should_exist? boolean @nil=false
---@return string? @absolute file path
function M.file(bufnr, should_exist)
  assert(bufnr ~= nil and bufnr ~= 0)

  if prefer.bo(bufnr, "buftype") ~= "" then return end

  local bufname = ni.buf_get_name(bufnr)
  if bufname == "" then return end

  local fpath
  if fs.is_absolute(bufname) then
    fpath = bufname
  else
    fpath = vim.fn.fnamemodify(bufname, "%:p")
  end

  if should_exist and not fs.file_exists(fpath) then return end

  return fpath
end

---based on buftype={help,""} and bufname
---@param bufnr integer
---@param should_exists? boolean @nil=false
---@return string? @absolute directory path
function M.dir(bufnr, should_exists)
  assert(bufnr ~= nil and bufnr ~= 0)

  --can not use project.working_root() here due to cyclic import
  local getcwd = vim.fn.getcwd

  if prefer.bo(bufnr, "buftype") ~= "" then return getcwd() end

  local bufname = ni.buf_get_name(bufnr)
  if bufname == "" then return getcwd() end

  local dir
  if fs.is_absolute(bufname) then
    dir = fs.parent(bufname)
  else
    dir = vim.fn.fnamemodify(bufname, "%:p:h")
  end

  if should_exists and not fs.dir_exists(dir) then return end
  return dir
end

return M
