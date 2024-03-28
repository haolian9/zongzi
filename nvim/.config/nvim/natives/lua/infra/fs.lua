--best practices
--* avoid vim.fs
--* prefer uv.fs_*

local M = {}

local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("infra.fs")
local strlib = require("infra.strlib")

local uv = vim.loop
local api = vim.api

---see /usr/include/linux/stat.h
---* IFIFO  = 0o010000 -> 0x1000
---* IFCHR  = 0o020000 -> 0x2000
---* IFDIR  = 0o040000 -> 0x4000
---* IFBLK  = 0o060000 -> 0x6000
---* IFREG  = 0o100000 -> 0x8000
---* IFLNK  = 0o120000 -> 0xa000
---* IFSOCK = 0o140000 -> 0xc000
local IFIFO = 0x1000
local IFCHR = 0x2000
local IFDIR = 0x4000
local IFBLK = 0x6000
local IFREG = 0x8000
local IFLNK = 0xa000
local IFSOCK = 0xc000

local function is_type(mode, mask) return bit.band(mode, mask) == mask end

do
  local max_link_level = 8

  ---@return 'directory'|'file'|'fifo'|'char'|'block'|'socket'
  local function resolve_symlink_type(fpath)
    local next = fpath
    local remain = max_link_level
    while remain > 0 do
      remain = remain - 1

      next = uv.fs_realpath(next)
      local stat = uv.fs_stat(next)

      local type
      if is_type(stat.mode, IFLNK) then
        type = "link"
      elseif is_type(stat.mode, IFDIR) then
        type = "directory"
      elseif is_type(stat.mode, IFREG) then
        type = "file"
      elseif is_type(stat.mode, IFIFO) then
        type = "fifo"
      elseif is_type(stat.mode, IFCHR) then
        type = "char"
      elseif is_type(stat.mode, IFBLK) then
        type = "block"
      elseif is_type(stat.mode, IFSOCK) then
        type = "socket"
      else
        error(string.format("unexpected file type, mode=%s file=%s", stat.mode, fpath))
      end
      ---@diagnostic disable-next-line: return-type-mismatch
      if type ~= "link" then return type end
    end

    error(string.format("too many levels symlink; file=%s, max=%d", fpath, max_link_level))
  end

  ---@param root string @absolute path
  ---@param resolve_symlink nil|boolean @nil=true
  ---@return fun():string?,string? @iterator -> {basename, file-type}
  function M.iterdir(root, resolve_symlink)
    local ok, scanner = pcall(uv.fs_scandir, root)
    if not ok then
      jelly.warn("failed to scan dir=%s, err=%s", root, scanner)
      return function() end
    end

    if scanner == nil then return function() end end

    -- must be set to true explictly
    if resolve_symlink == true then return function() return uv.fs_scandir_next(scanner) end end

    return function()
      local fname, ftype = uv.fs_scandir_next(scanner)
      if ftype ~= "link" then return fname, ftype end
      return fname, resolve_symlink_type(M.joinpath(root, fname))
    end
  end

  ---@param root string @absolute path
  ---@param resolve_symlink nil|boolean @nil=true
  ---@return fun():string? @iterator -> basename
  function M.iterfiles(root, resolve_symlink)
    local iter = M.iterdir(root, resolve_symlink)
    return function()
      for fname, ftype in iter do
        if ftype == "file" then return fname end
      end
    end
  end
end

---@param ... string
---@return string
function M.joinpath(...)
  local args
  do
    args = { ... }
    if #args == 0 then return "" end
    if #args == 1 then return args[1] end
    -- no trailing /
    args[#args] = strlib.rstrip(args[#args], "/")
  end

  local parts
  do
    parts = args
    -- new root
    for i = #args, 2, -1 do
      if strlib.startswith(args[i], "/") then
        parts = fn.slice(args, i, #args + 1)
        break
      end
    end
  end

  local path
  do
    -- stole from: https://github.com/neovim/neovim/commit/189fb6203262340e7a59e782be970bcd8ae28e61#diff-fecfd503a1c28e0a28a91da0294b12dbc72f081cb12434459648a44f641b68d9
    path = fn.join(parts, "/")
    path = string.gsub(path, [[/+]], "/")
  end

  return path
end

function M.relative_path(root, subdir)
  if strlib.endswith(root, "/") or vim.endswith(root, "/") then return end
  if root == subdir then return "" end
  if not strlib.startswith(subdir, root) then return end
  return string.sub(subdir, #root + 2)
end

---@param path string
---@return boolean
function M.is_absolute(path)
  if not strlib.startswith(path, "/") then return false end
  -- ..
  if strlib.find(path, "/../") then return false end
  if strlib.endswith(path, "/..") then return false end
  -- .
  if strlib.find(path, "/./") then return false end
  if strlib.endswith(path, "/.") then return false end

  return true
end

---assumes it's a lua plugin and with filesystem layout &rtp/lua/{plugin_name}/*.lua
---@param plugin_name string
---@param fname string? @nil=init.lua
function M.resolve_plugin_root(plugin_name, fname)
  fname = fname or "init.lua"
  local files = api.nvim_get_runtime_file(M.joinpath("lua", plugin_name, fname), false)
  assert(files and #files == 1)
  return string.sub(files[1], 1, -(#fname + 2))
end

---@param path string @absolute path, no `/` in the tail
---@return string
function M.parent(path)
  assert(path ~= "")
  if path == "/" then return "/" end
  path = strlib.rstrip(path, "/")

  local found = assert(strlib.rfind(path, "/"))
  local parent = string.sub(path, 1, found - 1)
  if parent == "" then return "/" end
  return parent
end

---@param path string
---@return string
function M.basename(path)
  assert(path ~= "")
  if path == "/" then return "/" end
  path = strlib.rstrip(path, "/")

  local found = strlib.rfind(path, "/")
  if found == nil then return path end
  return string.sub(path, found + 1)
end

---like pathshorten() except the **last two** will not be shorten
---trailing `/` will be erased
---@param path string @absolute path
---@return string
function M.shorten(path)
  assert(path ~= "" and path ~= nil)
  if path == "/" then return "/" end
  local parts = fn.split(strlib.rstrip(path, "/"), "/")
  ---head
  if #parts > 1 and parts[1] ~= "" then parts[1] = string.sub(parts[1], 1, 1) end
  ---middles if any
  if #parts > 3 then
    for i in fn.range(2, #parts - 2 + 1) do
      parts[i] = string.sub(parts[i], 1, 1)
    end
  end
  return table.concat(parts, "/")
end

function M.file_exists(fpath)
  local stat = uv.fs_stat(fpath)
  if stat == nil then return false end
  return is_type(stat.mode, IFREG)
end

function M.dir_exists(fpath)
  local stat = uv.fs_stat(fpath)
  if stat == nil then return false end
  return is_type(stat.mode, IFDIR)
end

---@param path string
---@return string
function M.stem(path)
  assert(path ~= "")
  if path == "/" then return "/" end

  local base = M.basename(path)
  local at = strlib.rfind(base, ".")
  if at == nil then return base end
  if at == 1 then return base end
  return string.sub(base, 1, at - 1)
end

---@param path string
---@return string? @contains the leading dot
function M.suffix(path)
  assert(path ~= "")
  if path == "/" then return end

  local at = strlib.rfind(path, ".")
  if at == nil then return end
  return string.sub(path, at)
end

return M
