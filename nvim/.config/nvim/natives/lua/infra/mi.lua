---customized nvim api

local M = {}

local ex = require("infra.ex")
local feedkeys = require("infra.feedkeys")
local ni = require("infra.ni")

do
  local function in_expected_mode()
    local mode = ni.get_mode().mode
    local m = string.sub(mode, 1, 1)

    if m == "n" then return true end
    if m == "v" then return true end
    if m == "V" then return true end
    if m == "s" then return true end
    if m == "R" then return true end
    if mode == "CTRL-V" then return true end
    if mode == "CTRL-Vs" then return true end
    if mode == "CTRL-S" then return true end

    return false
  end

  ---@param fmt string @no need to prefix with :
  ---@param ... any
  function M.setcmdline(fmt, ...)
    if not in_expected_mode() then error("unreachable") end

    local str = string.format(fmt, ...)

    feedkeys.codes(":", "n")
    vim.schedule(function() --another vim.schedule magic
      assert(ni.get_mode().mode == "c")
      vim.fn.setcmdline(str, #str + #":") --pos in bytes
    end)
  end
end

---@param winid integer
---@return boolean
function M.win_is_float(winid) return ni.win_get_config(winid).relative ~= "" end

---@param winid integer
---@return boolean
function M.win_is_landed(winid) return ni.win_get_config(winid).relative == "" end

---@param what 'cache'|'config'|'data'|'run'|'state'
---@return string
function M.stdpath(what)
  local result = vim.fn.stdpath(what)
  assert(type(result) == "string")
  return result
end

---it places cursor right after the insertion position
---note: it's an async op
function M.stopinsert()
  if ni.get_mode().mode == "i" then
    feedkeys("<esc>l", "n")
  else
    ex("stopinsert")
  end
end

---@param bufnr integer
---@param enter boolean
---@param opts vim.api.keyset.win_config
---@return integer winid
function M.open_win(bufnr, enter, opts)
  local winid = ni.open_win(bufnr, enter, opts)

  --no sharing loclist
  vim.fn.setloclist(winid, {}, "f")

  return winid
end

---unlike fn.bufnr(), it accepts exact name rather than a pattern
---@param exact integer|string @exact name or winnr
---@param create? boolean @create a buffer on need
---@return -1|integer @the bufnr
---@return boolean @created or not
---@see vim.fn.bufnr
function M.bufnr(exact, create)
  assert(type(exact) == "string" and exact ~= "")
  if create == nil then create = false end

  local bufnr

  bufnr = vim.fn.bufnr(string.format("^%s$", exact), false)
  if bufnr ~= -1 then return bufnr, false end
  if not create then return bufnr, false end

  return vim.fn.bufadd(exact), true
end

---{cwd:string,env:table,stdin:'pipe'|'null',on_exit:fun(jobid:integer,exit_code:integer,event:'exit')}
---@class infra.mi.TermSpec
---@field cwd? string
---@field env? {string:string}
---@field stdin? 'pipe'|'null'
---@field on_stdout? fun(jobid:integer, data:any, event:'stdout')
---@field on_stderr? fun(jobid:integer, data:any, event:'stderr')
---@field on_exit? fun(jobid:integer, exit_code:integer, event:'exit')

---turn current win&buf into a terminal
---@param cmd string|string[]
---@param spec infra.mi.TermSpec
---@return integer @jobid
function M.become_term(cmd, spec)
  assert(spec ~= nil)
  ---@diagnostic disable: inject-field
  spec.term = true
  if spec.stdout_buffered == nil then spec.stdout_buffered = false end
  if spec.stderr_buffered == nil then spec.stderr_buffered = false end
  if spec.stdin == nil then spec.stdin = "pipe" end

  return vim.fn.jobstart(cmd, spec)
end

---@param winid? 0|integer
---@return integer
function M.resolve_winid_param(winid)
  if winid == nil or winid == 0 then return ni.get_current_win() end
  assert(winid >= 1000)
  return winid
end

---@param bufnr? 0|integer
---@return integer
function M.resolve_bufnr_param(bufnr)
  if bufnr == nil or bufnr == 0 then return ni.get_current_buf() end
  return bufnr
end

---@param bufnr integer
---@param ns integer @0=global
---@param lnum integer @0-based
---@param higroup string
---@return integer extmark-id
function M.buf_highlight_line(bufnr, ns, lnum, higroup)
  bufnr = M.resolve_bufnr_param(bufnr)
  return ni.buf_set_extmark(bufnr, ns, lnum, 0, { hl_group = higroup, end_row = lnum + 1, end_col = 0 })
end

---@param winid? integer
function M.redraw_win(winid)
  winid = M.resolve_winid_param(winid)
  ni.x.redraw({ win = winid, valid = true, flush = true })
end

return M
