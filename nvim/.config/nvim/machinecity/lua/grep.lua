local M = {}

local project = require("infra.project")
local fn = require("infra.fn")
local vsel = require("infra.vsel")
local subprocess = require("infra.subprocess")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("grep")

local qltoggle = require("qltoggle")

local callbacks = {
  output = function(pattern, root)
    assert(pattern and root)

    -- why:
    -- * git grep and rg output relative path
    -- * nvim treats non-absolute path in qflist/loclist relative to cwd
    local resolve_fpath = (function()
      local cwd = vim.fn.getcwd()

      if cwd == root then return function(relpath)
        return relpath
      end end

      return function(relpath)
        return fs.joinpath(root, relpath)
      end
    end)()

    -- :h setqflist-what
    -- qflist and loclist shares the same structure
    local rg_to_qf = function(line)
      -- lno, col: 1-based
      local file, lno, col, text = unpack(fn.split(line, ":", 3))
      assert(file and lno and col and text)
      return {
        filename = resolve_fpath(file),
        col = col,
        lnum = lno,
        text = text,
      }
    end

    return function(output_iter)
      local batch_size = 128
      local output_to_qflist = function(output_lines)
        -- git grep's output happens to be same as rg
        return fn.concrete(fn.map(rg_to_qf, output_lines))
      end

      -- qflist is globally unique, while loclist is bound to buffer
      vim.fn.setqflist({}, "r", { title = "grep://" .. pattern, items = {} })
      qltoggle.open_qflist()

      for lines in fn.batch(output_iter, batch_size) do
        local copy = lines
        vim.schedule(function()
          vim.fn.setqflist({}, "a", { items = output_to_qflist(copy) })
        end)
      end
    end
  end,
  exit = function(cmd, args, path)
    return function(exit_code)
      -- rg, git grep shares same meaning on return code 0 and 1
      -- 0: no error, has at least one match
      -- 1: no error, has none match
      if exit_code == 0 then return end
      if exit_code == 1 then return end
      vim.schedule(function()
        jelly.err("grep failed: %s args=%s, cwd=%s", cmd, table.concat(args), path)
      end)
    end
  end,
}

local rg = function(path, pattern, extra_args)
  assert(pattern ~= nil)
  if path == nil then return jelly.warn("path is nil, rg canceled") end

  local args = {
    "--column",
    "--line-number",
    "--no-heading",
    "--color=never",
    "--hidden",
    "--max-columns=512",
    "--smart-case",
  }
  do
    if extra_args ~= nil then fn.list_extend(args, extra_args) end
    table.insert(args, "--")
    table.insert(args, pattern)
  end

  subprocess.asyncrun("rg", { args = args, cwd = path }, callbacks.output(pattern, path), callbacks.exit("rg", args, path))
end

local function gitgrep(path, pattern, extra_args)
  assert(pattern ~= nil)
  if path == nil then return jelly.warn("path is nil, git grep canceled") end

  local args = { "grep", "--line-number", "--column", "--no-color" }
  do
    if extra_args ~= nil then fn.list_extend(args, extra_args) end
    table.insert(args, "--")
    table.insert(args, pattern)
  end

  subprocess.asyncrun("git", { args = args, cwd = path }, callbacks.output(pattern, path), callbacks.exit("gitgrep", args, path))
end

local function make_runner(runner)
  -- it happens to be same to the output of rg and git grep

  local determiners = {
    repo = project.git_root,
    cwd = project.working_root,
    dot = function()
      return vim.fn.expand("%:p:h")
    end,
  }

  return {
    input = function(path_determiner)
      local determiner = assert(determiners[path_determiner], "unknown path determiner")
      local path = assert(determiner(), "no available path")
      local regex = vim.fn.input("grep ")
      if regex == "" then return end
      runner(path, regex)
    end,
    vsel = function(path_determiner)
      local determiner = assert(determiners[path_determiner], "unknown path determiner")
      local path = assert(determiner(), "no available path")
      local fixed = vsel.oneline_text()
      if fixed == nil then return end
      runner(path, fixed, { "--fixed-strings" })
    end,
    text = function(path_determiner, regex)
      local determiner = assert(determiners[path_determiner], "unknown path determiner")
      local path = assert(determiner(), "no available path")
      runner(path, regex)
    end,
  }
end

M.rg = make_runner(rg)
M.git = make_runner(gitgrep)

return M
