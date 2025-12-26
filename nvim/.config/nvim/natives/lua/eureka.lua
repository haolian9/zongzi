local M = {}

local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("eureka", "info")
local listlib = require("infra.listlib")
local project = require("infra.project")
local subprocess = require("infra.subprocess")
local vsel = require("infra.vsel")

local puff = require("puff")
local sting = require("sting")

local Converter
do
  ---@class eureka.Converter
  ---@field realpath fun(path: string): string
  local Impl = {}

  Impl.__index = Impl

  ---:h setqflist-what
  ---qflist and loclist shares the same structure
  function Impl:__call(line)
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
    return setmetatable({ realpath = realpath }, Impl)
  end
end

local function StdoutCollector()
  local chunks = {}
  local stdout_closed = false
  return {
    ---@param data string?
    on_stdout = function(data)
      if data ~= nil then return table.insert(chunks, data) end
      stdout_closed = true
    end,
    ---@param pattern string
    ---@param root string
    feed_vim = function(pattern, root)
      assert(stdout_closed)

      vim.schedule(function()
        local converter = Converter(root)
        local qf = sting.quickfix.shelf(string.format("eureka:%s", pattern))

        qf:reset()
        for line in subprocess.iter_lines(chunks) do
          qf:append(converter(line))
        end
        qf:feed_vim(true, false)
      end)
    end,
  }
end

---@alias Source fun(path: string, pattern: string, extra_args?: string[])

---@type Source
local function rg(path, pattern, extra_args)
  assert(pattern ~= nil)
  if path == nil then return jelly.warn("path is nil, rg canceled") end

  local args = { "--column", "--line-number", "--no-heading", "--color=never", "--hidden", "--max-columns=512", "--smart-case" }
  do
    if extra_args ~= nil then listlib.extend(args, extra_args) end
    table.insert(args, "--")
    table.insert(args, pattern)
  end

  jelly.debug("rg: %s", args)

  local collector = StdoutCollector()

  subprocess.spawn("rg", { args = args, cwd = path }, collector.on_stdout, function(exit_code)
    -- 0: no error, has at least one match
    -- 1: no error, has none match
    if not (exit_code == 0 or exit_code == 1) then return jelly.err("rg rc=%s args=%s, cwd=%s", exit_code, args, path) end
    collector.feed_vim(pattern, path)
  end)
end

---@type Source
local function gitgrep(path, pattern, extra_args)
  assert(pattern ~= nil)
  if path == nil then return jelly.warn("path is nil, git grep canceled") end

  local args = { "grep", "-I", "--line-number", "--column", "--no-color" }
  do
    ---smart-case
    if string.find(pattern, "%u") == nil then table.insert(args, "--ignore-case") end
    if extra_args ~= nil then listlib.extend(args, extra_args) end
    table.insert(args, "--")
    table.insert(args, pattern)
  end

  jelly.debug("git: %s", args)

  local collector = StdoutCollector()

  subprocess.spawn("git", { args = args, cwd = path }, collector.on_stdout, function(exit_code)
    -- 0: no error, has at least one match
    -- 1: no error, has none match
    if not (exit_code == 0 or exit_code == 1) then return jelly.err("git rc=%s args=%s, cwd=%s", exit_code, args, path) end
    collector.feed_vim(pattern, path)
  end)
end

local API
do
  ---@class eureka.API
  ---@field private source fun(path: string, pattern: string, extra_args?: string[])
  local Impl = {}
  Impl.__index = Impl

  ---@param root string
  function Impl:input(root)
    puff.input({ prompt = "eureka", icon = "🔍", startinsert = "a", remember = "eureka" }, function(pattern)
      if pattern == nil or pattern == "" then return end
      self.source(root, pattern)
    end)
  end

  ---@param root string
  function Impl:vsel(root)
    local fixed = vsel.oneline_text()
    if fixed == nil then return end
    self.source(root, fixed, { "--fixed-strings" })
  end

  ---@param root string
  ---@param pattern string
  function Impl:text(root, pattern) self.source(root, pattern) end

  ---@param path string
  ---@param pattern string
  ---@param extra_args? string[]
  function Impl:__call(path, pattern, extra_args) self.source(path, pattern, extra_args) end

  function API(source) return setmetatable({ source = source }, Impl) end
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
