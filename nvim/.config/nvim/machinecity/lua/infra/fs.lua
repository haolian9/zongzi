local M = {}

local uv = vim.loop

local fn = require("infra.fn")
local strlib = require("infra.strlib")

M.sep = "/"

---@return string @the resolved file type
local function resolve_symlink_type(fpath)
  -- todo: vim.fn.resolve?
  local function istype(mode, mask)
    return bit.band(mode, mask) == mask
  end
  local max_link_level = 8

  local next = fpath
  local remain = max_link_level
  while remain > 0 do
    remain = remain - 1

    next = uv.fs_realpath(next)
    local stat = uv.fs_stat(next)

    -- IFIFO  = 0o010000 -> 0x1000
    -- IFCHR  = 0o020000 -> 0x2000
    -- IFDIR  = 0o040000 -> 0x4000
    -- IFBLK  = 0o060000 -> 0x6000
    -- IFREG  = 0o100000 -> 0x8000
    -- IFLNK  = 0o120000 -> 0xa000
    -- IFSOCK = 0o140000 -> 0xc000

    local type
    if istype(stat.mode, 0xa000) then
      type = "link"
    elseif istype(stat.mode, 0x4000) then
      type = "directory"
    elseif bit.band(stat.mode, 0x8000) then
      type = "file"
    elseif bit.band(stat.mode, 0x1000) then
      type = "fifo"
    elseif bit.band(stat.mode, 0x2000) then
      type = "char"
    elseif bit.band(stat.mode, 0x6000) then
      type = "block"
    elseif bit.band(stat.mode, 0xc000) then
      type = "socket"
    else
      error(string.format("unexpected file type, mode=%s file=%s", stat.mode, fpath))
    end
    if type ~= "link" then return type end
  end

  error(string.format("too many levels symlink; file=%s, max=%d", fpath, max_link_level))
end

---@param root string @absolute path
---@param resolve_symlink nil|boolean @nil=true
---@return function @iterator -> {basename, file-type}
M.iterdir = function(root, resolve_symlink)
  local ok, scanner = pcall(uv.fs_scandir, root)
  if not ok then
    vim.notify(scanner, vim.log.levels.ERROR)
    return function() end
  end

  if scanner == nil then return function() end end

  -- must be set to true explictly
  if resolve_symlink == true then return function()
    return uv.fs_scandir_next(scanner)
  end end

  return function()
    local fname, ftype = uv.fs_scandir_next(scanner)
    if ftype ~= "link" then return fname, ftype end
    return fname, resolve_symlink_type(M.joinpath(root, fname))
  end
end

function M.joinpath(...)
  local args = { ... }
  assert(#args >= 2)

  local parts = {}

  -- root part
  do
    if args[1] == "/" then
      table.insert(parts, "")
    elseif args[1] == "" then
      -- then no parent
    else
      table.insert(parts, strlib.rstrip(args[1], M.sep))
    end
  end

  -- rest parts
  for i = 2, #args do
    table.insert(parts, strlib.strip(args[i], M.sep))
  end

  return fn.join(parts, M.sep)
end

function M.relative_path(root, subdir)
  if vim.endswith(root, "/") or vim.endswith(root, "/") then return end
  if root == subdir then return "" end
  if not vim.startswith(subdir, root) then return end
  return string.sub(subdir, #root + 2)
end

---@param path string
---@return boolean
function M.is_absolute(path)
  return vim.startswith(path, "/")
end

return M
