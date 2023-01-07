--
-- design choices
-- * only for files of source code
-- * no communicate with external formatting program
-- * run runners by order, crashing wont make original buffer dirty
-- * suppose all external formatting program do inplace
--

local M = {}

local api = vim.api
local uv = vim.loop

local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("formatter")
local subprocess = require("infra.subprocess")
local project = require("infra.project")
local fs = require("infra.fs")
local ex = require("infra.ex")

local mktempfile = os.tmpname

local resolve_stylua_config = (function()
  local found
  local function resolve()
    local function find(root)
      if root == nil then return end
      for _, basename in ipairs({ "stylua.toml", ".stylua.toml" }) do
        local path = fs.joinpath(root, basename)
        local stat = uv.fs_stat(path)
        if stat ~= nil then return path end
      end
    end
    return find(project.git_root()) or find(project.working_root()) or find(vim.fn.stdpath("config"))
  end

  return function()
    if found == nil then found = resolve() end
    return found
  end
end)()

-- all runners should modify the file inplace
---@type { [string]: fun(fpath: string): boolean}
local runners = {
  zig = function(fpath)
    local cp = subprocess.run("zig", { args = { "fmt", "--ast-check", fpath } })
    return cp.exit_code == 0
  end,
  stylua = function(fpath)
    local conf = resolve_stylua_config()
    if conf == nil then return false end
    local cp = subprocess.run("stylua", { args = { "--config-path", conf, fpath } })
    return cp.exit_code == 0
  end,
  isort = function(fpath)
    local cp = subprocess.run("isort", { args = { "--quiet", "--profile", "black", fpath } })
    return cp.exit_code == 0
  end,
  black = function(fpath)
    local cp = subprocess.run("black", { args = { "--quiet", "--target-version", "py310", "--line-length", "256", fpath } })
    return cp.exit_code == 0
  end,
  go = function(fpath)
    local cp = subprocess.run("gofmt", { args = { "-w", fpath } })
    return cp.exit_code == 0
  end,
  ["clang-format"] = function(fpath)
    local cp = subprocess.run("clang-format", { args = { "-i", fpath } })
    return cp.exit_code == 0
  end,
  fnlfmt = function(fpath)
    local cp = subprocess.run("fnlfmt", { args = { "--fix", fpath } })
    return cp.exit_code == 0
  end,
  rustfmt = function(fpath)
    local cp = subprocess.run("rustfmt", { args = { fpath } })
    return cp.exit_code == 0
  end,
}

-- {ft: {profile: [(runner-name, runner)]}}
local profiles = {}
do
  local defines = {
    { "lua", "default", { "stylua" } },
    { "zig", "default", { "zig" } },
    { "python", "default", { "isort", "black" } },
    { "go", "default", { "go" } },
    { "c", "default", { "clang-format" } },
    { "fennel", "default", { "fnlfmt" } },
    { "rust", "default", { "rustfmt" } },
  }
  for _, def in ipairs(defines) do
    local ft, pro, runs = unpack(def)
    if profiles[ft] == nil then profiles[ft] = {} end
    if profiles[ft][pro] ~= nil then error("duplicate definitions for profile " .. pro) end
    profiles[ft][pro] = fn.concrete(fn.map(function(name)
      local r = runners[name]
      assert(r, "no such runner " .. name)
      return { name, r }
    end, runs))
  end
end

local regulator = {
  -- {bufnr: changetick}
  state = {},

  ---@param self table
  throttled = function(self, bufnr)
    local last = self.state[bufnr] or 0
    local now = api.nvim_buf_get_changedtick(bufnr)
    return last ~= now
  end,

  ---@param self table
  update = function(self, bufnr)
    self.state[bufnr] = api.nvim_buf_get_changedtick(bufnr)
  end,
}

---@param bufnr number
---@param callback fun()
local function keep_view(bufnr, callback)
  assert(bufnr)

  -- [(win_id, view)]
  local state = {}

  local bufinfo = vim.fn.getbufinfo(bufnr)[1]
  assert(bufinfo)

  for win_id in fn.list_iter(bufinfo.windows) do
    api.nvim_win_call(win_id, function()
      table.insert(state, { win_id, vim.fn.winsaveview() })
    end)
  end

  callback()

  for win_id, view in fn.list_iter_unpacked(state) do
    api.nvim_win_call(win_id, function()
      vim.fn.winrestview(view)
    end)
  end
end

function M.run(bufnr, ft, profile)
  bufnr = bufnr or api.nvim_get_current_buf()
  if not regulator:throttled(bufnr) then return jelly.info("no change") end

  ft = ft or api.nvim_buf_get_option(bufnr, "filetype")
  profile = profile or "default"

  local runs = fn.get(profiles, ft, profile) or {}

  if #runs == 0 then return jelly.info("no available formatting runners") end

  local tmpfpath = mktempfile()

  -- prepare tmpfile
  do
    jelly.info("using ft=%s, profile=%s, bufnr=%d, runners=%d", ft, profile, bufnr, #runs)
    local file, open_err = io.open(tmpfpath, "w")
    if not file then error(open_err) end
    for line in fn.list_iter(api.nvim_buf_get_lines(bufnr, 0, -1, true)) do
      assert(file:write(line))
      assert(file:write("\n"))
    end
    file:close()
  end

  -- runner pipeline against tmpfile
  for name, run in fn.list_iter_unpacked(runs) do
    if not run(tmpfpath) then
      jelly.warn("failed to run %s", name)
      subprocess.tail_logs()
      return
    end
  end

  -- sync back & save
  do
    local lines = {}
    for line in io.lines(tmpfpath) do
      table.insert(lines, line)
    end
    keep_view(bufnr, function()
      -- the reported errors are insane!
      pcall(api.nvim_buf_set_lines, bufnr, 0, -1, false, lines)
    end)
    api.nvim_buf_call(bufnr, function()
      ex("silent write")
    end)
    regulator:update(bufnr)
  end

  -- cleanup
  uv.fs_unlink(tmpfpath)
end

return M
