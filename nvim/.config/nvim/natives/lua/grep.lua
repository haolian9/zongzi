local M = {}

local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("grep")
local listlib = require("infra.listlib")
local project = require("infra.project")
local subprocess = require("infra.subprocess")
local vsel = require("infra.vsel")

local sting = require("sting")
local puff = require("puff")

local Converter
do
  ---@class grep.Converter
  ---@field realpath fun(path: string): string
  local Prototype = {}

  Prototype.__index = Prototype

  ---:h setqflist-what
  ---qflist and loclist shares the same structure
  function Prototype:__call(line)
    -- lno, col: 1-based
    local path, lno, col = string.match(line, "(.+):(%d+):(%d+):")
    assert(path and lno and col, line)
    local text_start = #path + #lno + #col + 3 + 1 -- 3=:::
    lno = tonumber(lno)
    col = tonumber(col)
    assert(lno and col)
    ---only keep the first 256 chars of text
    local text = string.sub(line, text_start, text_start + 256)

    ---why:
    ---* git grep and rg output relative path
    ---* nvim treats non-absolute path in qflist/loclist relative to cwd
    local abspath = self.realpath(path)

    return { filename = abspath, col = col, lnum = lno, text = text }
  end

  ---@param root string
  ---@return fun(line: string): sting.Pickle
  function Converter(root)
    local cwd = project.working_root()

    local realpath
    if cwd == root then
      realpath = function(path) return path end
    else
      realpath = function(path) return fs.joinpath(root, path) end
    end

    ---@diagnostic disable-next-line: return-type-mismatch
    return setmetatable({ realpath = realpath }, Prototype)
  end
end

local rg, gitgrep
do
  local function output_callback(pattern, root)
    assert(pattern and root)

    local converter = Converter(root)
    local qf = sting.quickfix.shelf(string.format("grep:%s", pattern))

    ---@param output_iter fun(): string?
    return function(output_iter)
      qf:reset()
      for line in output_iter do
        qf:append(converter(line))
      end
      qf:feed_vim(true, false)
    end
  end

  local function exit_callback(cmd, args, path)
    return function(exit_code)
      -- rg and git grep share same meaning on return code 0 and 1
      -- 0: no error, has at least one match
      -- 1: no error, has none match
      if exit_code == 0 then return end
      if exit_code == 1 then return end
      vim.schedule(function() jelly.err("grep failed: %s args=%s, cwd=%s", cmd, table.concat(args), path) end)
    end
  end

  ---@param path string
  ---@param pattern string
  ---@param extra_args? string[]
  function rg(path, pattern, extra_args)
    assert(pattern ~= nil)
    if path == nil then return jelly.warn("path is nil, rg canceled") end

    local args = { "--column", "--line-number", "--no-heading", "--color=never", "--hidden", "--max-columns=512", "--smart-case" }
    do
      if extra_args ~= nil then listlib.extend(args, extra_args) end
      table.insert(args, "--")
      table.insert(args, pattern)
    end

    subprocess.spawn("rg", { args = args, cwd = path }, output_callback(pattern, path), exit_callback("rg", args, path))
  end

  ---@param path string
  ---@param pattern string
  ---@param extra_args? string[]
  function gitgrep(path, pattern, extra_args)
    assert(pattern ~= nil)
    if path == nil then return jelly.warn("path is nil, git grep canceled") end

    local args = { "grep", "-I", "--line-number", "--column", "--no-color" }
    do
      ---smart-case
      if string.match(pattern, "%u") == nil then table.insert(args, "--ignore-case") end
      if extra_args ~= nil then listlib.extend(args, extra_args) end
      table.insert(args, "--")
      table.insert(args, pattern)
    end

    subprocess.spawn("git", { args = args, cwd = path }, output_callback(pattern, path), exit_callback("gitgrep", args, path))
  end
end

local API
do
  ---@class grep.API
  ---@field private source fun(path: string, pattern: string, extra_args?: string[])
  local Prototype = {}
  Prototype.__index = Prototype

  ---@param root string
  function Prototype:input(root)
    puff.input({ prompt = "grep", startinsert = true }, function(regex)
      if regex == nil or regex == "" then return end
      self.source(root, regex)
    end)
  end

  ---@param root string
  function Prototype:vsel(root)
    local fixed = vsel.oneline_text()
    if fixed == nil then return end
    self.source(root, fixed, { "--fixed-strings" })
  end

  ---@param root string
  ---@param regex string
  function Prototype:text(root, regex) self.source(root, regex) end

  ---@param path string
  ---@param pattern string
  ---@param extra_args? string[]
  function Prototype:__call(path, pattern, extra_args) self.source(path, pattern, extra_args) end

  function API(source) return setmetatable({ source = source }, Prototype) end
end

M.rg = API(rg)
M.git = API(gitgrep)

do
  local function main(meth)
    return function(...)
      local git_root = project.git_root()
      if git_root ~= nil then
        M.git[meth](M.git, git_root, ...)
      else
        M.rg[meth](M.rg, project.working_root(), ...)
      end
    end
  end
  M.vsel = main("vsel")
  M.input = main("input")
  M.text = main("text")
end

return M
