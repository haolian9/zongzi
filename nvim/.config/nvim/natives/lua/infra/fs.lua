--best practices
--* avoid vim.fs
--* prefer uv.fs_*

local M = {}

local itertools = require("infra.itertools")
local iuv = require("infra.iuv")
local jelly = require("infra.jellyfish")("infra.fs")
local strlib = require("infra.strlib")

local uv = vim.uv

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
  ---@alias SolidFileType 'directory'|'file'|'fifo'|'char'|'block'|'socket'

  ---@return SolidFileType?
  local function resolve_symlink_type(fpath)
    local realpath, realpath_err = uv.fs_realpath(fpath)
    if realpath == nil then return jelly.warn("realpath(%s): %s", fpath, realpath_err) end

    local stat, stat_err = uv.fs_stat(realpath)
    if stat == nil then return jelly.warn("stat(%s): %s", realpath, stat_err) end

    local type
    if is_type(stat.mode, IFLNK) then
      error("unreachable: realpath is still a symlink")
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
      return jelly.fatal("ValueError", "file: %s, stat.mode: %s", fpath, stat.mode)
    end

    return type
  end

  ---@param root string @absolute path
  ---@return fun(): string?, SolidFileType?
  function M.iterdir(root)
    local scanner = iuv.fs_scandir(root)

    return function()
      while true do
        local fname, ftype = uv.fs_scandir_next(scanner)
        if fname == nil then return end
        if ftype ~= "link" then return fname, ftype end

        ftype = resolve_symlink_type(M.joinpath(root, fname))
        if ftype ~= nil then return fname, ftype end
      end
    end
  end

  ---@param root string @absolute path
  ---@return fun(): string? @iterator -> basename
  function M.iterfiles(root)
    local iter = M.iterdir(root)
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
  local args = { ... }
  if #args == 0 then return "" end
  if #args == 1 then return args[1] end
  --deal with trailing /
  args[#args] = strlib.rstrip(args[#args], "/")

  ---@type string[]|fun(): string?
  local parts = args
  --deal with new root
  for i in itertools.range(#args - 1, 0, -1) do
    if strlib.startswith(args[i + 1], "/") then
      parts = itertools.slice(args, i, #args + 1)
      break
    end
  end

  local path
  path = itertools.join(parts, "/")
  path = string.gsub(path, [[/+]], "/")

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
  if strlib.contains(path, "/../") then return false end
  if strlib.endswith(path, "/..") then return false end
  -- .
  if strlib.contains(path, "/./") then return false end
  if strlib.endswith(path, "/.") then return false end

  return true
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
---@param slashless? boolean @nil=false
---@return string
function M.shorten(path, slashless)
  assert(path ~= "" and path ~= nil)
  if path == "/" then return "/" end

  local parts

  do --shorten
    parts = strlib.splits(strlib.rstrip(path, "/"), "/")
    --head
    if #parts > 1 and parts[1] ~= "" then parts[1] = string.sub(parts[1], 1, 1) end
    --middles if any
    if #parts > 3 then
      for i in itertools.range(2, #parts - 2 + 1) do
        parts[i] = string.sub(parts[i], 1, 1)
      end
    end
  end

  if slashless then
    for i = #parts, math.max(#parts - 1, 2), -1 do
      table.insert(parts, i, "/")
    end
    return table.concat(parts, "")
  else
    return table.concat(parts, "/")
  end
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

---it'll throw error when given path does not exist
---@param path string
---@return string
function M.abspath(path)
  --for ~, ~someone
  if strlib.startswith(path, "~") then path = vim.fn.expand(path) end
  if not strlib.startswith(path, "/") then path = string.format("%s/%s", vim.fn.getcwd(), path) end
  return iuv.fs_realpath(path)
end

return M
