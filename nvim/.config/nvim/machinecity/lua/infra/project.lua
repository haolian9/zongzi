-- provides project-related specs

local M = {}

local function find_git_root()
  local proc = io.popen("git rev-parse --show-toplevel 2>&1")
  if proc == nil then return end

  local output = proc:read("*a")
  if not vim.startswith(output, "/") then return end

  return string.match(output, "(.-)%s+$")
end

M.git_root = function()
  local root = find_git_root()
  M.git_root = function()
    return root
  end
  return root
end

M.working_root = function()
  return vim.fn.getcwd()
end

return M
