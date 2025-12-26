---@diagnostic disable: unused-local

-- protocol-like bufname used by plugins:
-- * term://
-- * man://
-- * kite://
-- * pstree://
-- * nag://

local M = {}

local fs = require("infra.fs")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local project = require("infra.project")
local strlib = require("infra.strlib")

---@alias lineexpr.BufnameResolver fun(bufnr:integer,bufname:string):string?

M.named = {
  ---http://a.b <- http://a.b
  ---@type lineexpr.BufnameResolver
  protocol = function(bufnr, bufname)
    if strlib.contains(bufname, "://") then return bufname end
  end,
  ---http://a.b -> http
  ---@type lineexpr.BufnameResolver
  short_protocol = function(bufnr, bufname)
    local start_at = strlib.find(bufname, "://")
    if start_at == nil then return end
    return string.sub(bufname, 1, start_at)
  end,
  ---@type lineexpr.BufnameResolver
  stem = function(bufnr, bufname)
    assert(bufname ~= "")
    return vim.fn.fnamemodify(bufname, ":t:r")
  end,
  ---@type lineexpr.BufnameResolver
  relative_stem = function(bufnr, bufname)
    assert(bufname ~= "")
    return vim.fn.fnamemodify(bufname, ":.:r")
  end,
  ---@type lineexpr.BufnameResolver
  basename = function(bufnr, bufname)
    assert(bufname ~= "")
    return fs.basename(bufname)
  end,
  ---@type lineexpr.BufnameResolver
  relative = function(bufnr, bufname)
    assert(bufname ~= "")
    return vim.fn.fnamemodify(bufname, ":.")
  end,
}

M.unnamed = {
  ---@type lineexpr.BufnameResolver
  filetype = function(bufnr, bufname)
    local ft = prefer.bo(bufnr, "filetype")
    if ft == "qf" then
      local winid = ni.get_current_win()
      if ni.win_get_buf(winid) ~= bufnr then return string.format("qf://%d", bufnr) end
      local wintype = vim.fn.win_gettype(winid)
      if wintype == "quickfix" then return string.format("qf://%s", vim.fn.getqflist({ title = 1 }).title) end
      if wintype == "loclist" then return string.format("loc://%s", vim.fn.getloclist(winid, { title = 1 }).title) end
      assert(false, "unexpected wintype=" .. wintype)
    end
    if ft == "help" then return string.format("help://%s", vim.fn.fnamemodify(bufname, ":t:r")) end
    if ft == "git" then return string.format("git://", project.working_root()) end
    if ft == "checkhealth" then return "checkhealth" end
  end,
  ---@type lineexpr.BufnameResolver
  short_filetype = function(bufnr, bufname)
    local ft = prefer.bo(bufnr, "filetype")
    if ft == "qf" then
      local winid = ni.get_current_win()
      if ni.win_get_buf(winid) ~= bufnr then return "qf" end
      local wintype = vim.fn.win_gettype(winid)
      if wintype == "quickfix" then return "qf" end
      if wintype == "loclist" then return "loc" end
      assert(false, "unexpected wintype=" .. wintype)
    end
    if ft == "help" then return "help" end
    if ft == "git" then return "git" end
    if ft == "checkhealth" then return "health" end
  end,
  ---@type lineexpr.BufnameResolver
  number = function(bufnr, bufname) return string.format("#%d", bufnr) end,
}

return M
