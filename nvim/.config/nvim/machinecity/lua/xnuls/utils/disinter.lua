-- disinster lua modules in a directory

local M = {}

local fs = require("infra.fs")
local fn = require("infra.fn")

local basedir = string.format("%s/%s", vim.fn.stdpath("config"), "lua")

-- * with .lua sufix
-- * without _ prefix
M.local_plugins = function(excludes)
  excludes = excludes or { "init" }

  local root = string.format("%s/%s", basedir, "locals/plugins")
  local iter = fs.iterdir(root)

  local suffice = function(fname, ftype)
    if ftype ~= "file" then return false end

    if not vim.endswith(fname, ".lua") then return false end

    if vim.startswith(fname, "_") then return false end

    return true
  end

  return function()
    for fname, ftype in iter do
      if suffice(fname, ftype) then
        local stem = string.sub(fname, 0, #fname - 4)
        if fn.contains(excludes, stem) then return stem end
      end
    end
  end
end

-- .lua or subdir
M.local_submods = function(mod_path)
  local root = string.format("%s/%s", basedir, mod_path)
  local iter = fs.iterdir(root)

  return function()
    for fname, ftype in iter do
      if ftype == "directory" then
        return fname
      elseif ftype == "file" then
        if vim.endswith(fname, ".lua") then return string.sub(fname, 0, #fname - 4) end
      end
    end
  end
end

return M
