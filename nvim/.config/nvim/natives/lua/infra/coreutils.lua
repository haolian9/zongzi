-- prefer iuv.fs_* than vim.fn.*

local M = {}

local ni = require("infra.ni")
local uv = vim.uv

local bufpath = require("infra.bufpath")
local bufrename = require("infra.bufrename")
local fs = require("infra.fs")
local iuv = require("infra.iuv")
local jelly = require("infra.jellyfish")("infra.coreutils")
local strlib = require("infra.strlib")

function M.touch(fpath)
  local file, err = iuv.fs_open(fpath, "a", tonumber("600", 8))
  if err ~= nil then error(err) end
  iuv.fs_close(file)
end

function M.rm_filebuf(bufnr)
  if bufnr == nil or bufnr == 0 then bufnr = ni.get_current_buf() end

  local path = bufpath.file(bufnr, true)
  if path ~= nil then
    local _, errmsg = iuv.fs_unlink(path)
    if errmsg then return jelly.err(errmsg) end
  end

  ni.buf_delete(bufnr, { force = true })
  jelly.info("removed file: %s, buf: %s", path, bufnr)
end

function M.rename_filebuf(bufnr, fname)
  assert(fname ~= nil and fname ~= "")
  if bufnr == nil or bufnr == 0 then bufnr = ni.get_current_buf() end

  local path = bufpath.file(bufnr, true)

  local newpath
  do
    if path ~= nil then
      newpath = fs.joinpath(fs.parent(path), fname)
    else
      newpath = fname
    end
    if path == newpath then return jelly.debug("same name") end
  end

  if path ~= nil then -- the buf being renamed is a real file
    local _, errmsg = iuv.fs_rename(path, newpath)
    if errmsg then return jelly.err(errmsg) end
  end

  bufrename(bufnr, newpath)
  jelly.info("renamed to %s", newpath)
end

---@return string
function M.whoami() return tostring(uv.getuid()) end

---@param path string @absolute path
---@param mode ?number @default 0o700
---@param exists_ok ?boolean @default true
---@return boolean
function M.mkdir(path, mode, exists_ok)
  mode = mode or tonumber("700", 8)
  local _ = exists_ok

  -- iuv.fs_mkdir did not support `p` flag
  local suc = vim.fn.mkdir(path, "p", mode)
  return suc == 1
end

function M.cat(path)
  local file = io.open(path, "r")
  assert(file, "open failed")
  local content = file:read("*a")
  file:close()

  return content
end

---@return fun(): string?
function M.cmdline()
  local path = string.format("/proc/%d/cmdline", uv.os_getpid())
  local content = M.cat(path)
  return strlib.iter_splits(content, "\0")
end

function M.which(name)
  local found = vim.fn.exepath(name)
  if found == "" then return end
  return found
end

return M
