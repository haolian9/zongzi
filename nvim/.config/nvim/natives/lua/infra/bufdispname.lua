---@diagnostic disable: unused-local

-- protocol-like bufname used by plugins:
-- * term://
-- * man://
-- * kite://
-- * pstree://
-- * nag://

local M = {}

local prefer = require("infra.prefer")
local project = require("infra.project")
local strlib = require("infra.strlib")

---@alias infra.bufdispname.resolver fun(bufnr: number, bufname: string): string?

M.named = {
  ---http://a.b <- http://a.b
  ---@param bufnr integer
  ---@param bufname string
  ---@return string?
  protocol = function(bufnr, bufname)
    if strlib.find(bufname, "://") ~= nil then return bufname end
  end,
  ---http <- http://a.b
  ---@param bufnr integer
  ---@param bufname string
  ---@return string?
  short_protocol = function(bufnr, bufname)
    local start_at = strlib.find(bufname, "://")
    if start_at == nil then return end
    return string.sub(bufname, 1, start_at)
  end,
  ---@param bufnr integer
  ---@param bufname string
  ---@return string
  stem = function(bufnr, bufname)
    assert(bufname ~= "")
    return vim.fn.fnamemodify(bufname, ":t:r")
  end,
  ---@param bufnr integer
  ---@param bufname string
  ---@return string
  relative_stem = function(bufnr, bufname)
    assert(bufname ~= "")
    return vim.fn.fnamemodify(bufname, ":.:r")
  end,
}

M.unnamed = {
  ---@param bufnr integer
  ---@param bufname string
  ---@return string?
  filetype = function(bufnr, bufname)
    local ft = prefer.bo(bufnr, "filetype")
    if ft == "qf" then return string.format("quickfix://%d", bufnr) end
    if ft == "help" then return string.format("help://%s", vim.fn.fnamemodify(bufname, ":t:r")) end
    if ft == "git" then return string.format("git://", project.working_root()) end
    if ft == "checkhealth" then return "checkhealth" end
  end,
  ---@param bufnr integer
  ---@param bufname string
  ---@return string?
  short_filetype = function(bufnr, bufname)
    local ft = prefer.bo(bufnr, "filetype")
    if ft == "qf" then return "quickfix" end
    if ft == "help" then return "help" end
    if ft == "git" then return "git" end
    if ft == "checkhealth" then return "health" end
  end,
  ---@param bufnr integer
  ---@param bufname string
  ---@return string
  number = function(bufnr, bufname) return string.format("#%d", bufnr) end,
}

return M
