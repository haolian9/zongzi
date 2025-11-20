---provides project-related specs
local M = {}

local bufpath = require("infra.bufpath")
local LRU = require("infra.LRU")
local mi = require("infra.mi")
local strlib = require("infra.strlib")
local subprocess = require("infra.subprocess")

---@return string
function M.working_root()
  --- no uv.cwd() because it's not aware of tcd/cd
  return vim.fn.getcwd()
end

do
  ---@type {[string]: string|false} {path: git-root}
  local cache = LRU(64)

  ---@param bufnr? integer
  ---@return string?
  function M.git_root(bufnr)
    bufnr = mi.resolve_bufnr_param(bufnr)

    local basedir = bufpath.dir(bufnr, true)
    if basedir == nil then return end

    local root
    local held = cache[basedir]
    if held == nil then
      local result = subprocess.run("git", { args = { "rev-parse", "--show-toplevel" }, cwd = basedir }, "raw")
      if result.exit_code ~= 0 then
        root = nil
        cache[basedir] = false
      else
        root = result.stdout()
        assert(root ~= nil and root ~= "")
        root = strlib.rstrip(root)
        cache[basedir] = root
      end
    elseif held == false then
      root = nil
    else
      root = held
    end

    return root
  end
end

return M
