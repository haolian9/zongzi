local M = {}

local Augroup = require("infra.Augroup")
local bufrename = require("infra.bufrename")
local ex = require("infra.ex")
local jelly = require("infra.jellyfish")("windmill.engine", "info")
local prefer = require("infra.prefer")
local project = require("infra.project")
local unsafe = require("infra.unsafe")
local winsplit = require("infra.winsplit")

local api = vim.api

local facts = {
  totem = "windmill",
  tty_height = 10,
  window_height = 10,
  keep_focus = true,
}

local TermView
do
  local count = 0
  local function next_view_id()
    count = count + 1
    return count
  end

  ---@class windmill.engine.TermView
  ---@field private id integer @auto_increment count
  ---@field bufnr integer
  ---@field term_chan integer @term chan
  ---@field proc_chan integer @spawned process chan
  ---@field exit_code? integer @of the spawned process
  local Prototype = {}
  do
    Prototype.__index = Prototype

    function Prototype:write_all(data) vim.fn.chansend(self.term_chan, data) end

    function Prototype:deinit()
      vim.fn.chanclose(self.term_chan)
      self.term_chan = nil
      vim.fn.chanclose(self.proc_chan)
      self.proc_chan = nil
    end
  end
  ---@alias TermView windmill.engine.TermView

  ---@param winid integer
  ---@return TermView
  function TermView(winid)
    ---@type TermView
    local view = setmetatable({ id = next_view_id() }, Prototype)

    do
      local bufnr = api.nvim_create_buf(false, true) --no ephemeral here
      api.nvim_buf_set_var(bufnr, facts.totem, true)
      prefer.bo(bufnr, "bufhidden", "wipe")
      bufrename(bufnr, string.format("windmill://%d", view.id))

      local aug = Augroup.buf(bufnr)
      aug:once("TermClose", {
        callback = function(args)
          assert(args.buf == bufnr)
          assert(prefer.bo(bufnr, "buftype") == "terminal", "once job")
          unsafe.prepare_help_buffer(bufnr)
        end,
      })
      aug:once("BufWipeout", {
        callback = function()
          aug:unlink()
          if view.proc_chan == nil then return end
          vim.fn.jobclose(view.proc_chan)
        end,
      })

      view.bufnr = bufnr
    end

    api.nvim_win_set_buf(winid, view.bufnr)

    do
      local term_chan = api.nvim_open_term(view.bufnr, {
        on_input = function(event, term, _bufnr, data)
          local _, _, _ = event, term, _bufnr
          assert(view.proc_chan ~= nil)
          -- necessary for redirecting proc_chan.stdout -> libvterm.stdout -> proc.stdin
          -- eg, \27[6n
          vim.fn.chansend(view.proc_chan, data)
        end,
      })
      assert(term_chan ~= 0)
      --follow
      api.nvim_win_set_cursor(winid, { api.nvim_buf_line_count(view.bufnr), 0 })

      view.term_chan = term_chan
    end

    return view
  end
end

local state = {}
do
  ---should use and reuse only one window
  ---@type integer?
  state.winid = nil

  ---last view
  ---@type TermView?
  state.view = nil

  function state:is_win_valid()
    if self.winid == nil then return false end
    return api.nvim_win_is_valid(self.winid)
  end

  function state:has_one_running()
    if self.view == nil then return false end
    return self.view.exit_code == nil
  end
end

local function open_win()
  local winid
  do -- the same as `:copen`
    winsplit("below")
    ex("wincmd", "J")
    winid = api.nvim_get_current_win()
    if facts.keep_focus then ex("wincmd", "p") end

    api.nvim_win_set_height(winid, facts.window_height)
    prefer.wo(winid, "winfixheight", true)
  end

  do -- the same as nvim_open_win(style=minimal)
    local wo = prefer.win(winid)
    wo.number = false
    wo.relativenumber = false
    wo.cursorline = false
    wo.cursorcolumn = false
    wo.foldcolumn = "0"
    wo.list = false
    wo.signcolumn = "auto"
    wo.spell = false
    wo.colorcolumn = ""
  end

  return winid
end

---@param cmd string[]
---@param cwd? string @nil=cwd
function M.run(cmd, cwd)
  assert(#cmd > 0)
  cwd = cwd or project.working_root()

  if state:has_one_running() then return jelly.warn("windmill is still running, refuses to accept new work") end

  ---@type TermView
  local view
  do
    if not state:is_win_valid() then state.winid = open_win() end

    view = TermView(state.winid)

    view.proc_chan = vim.fn.jobstart(cmd, {
      cwd = cwd,
      width = vim.go.columns,
      height = facts.tty_height,
      pty = true,
      on_exit = function(job_id, exit_code, event)
        local _, _ = job_id, event
        view.exit_code = exit_code
        view:deinit()
      end,
      on_stdout = function(job_id, data, event)
        local _, _ = job_id, event
        view:write_all(data)
      end,
      on_stderr = function(job_id, data, event)
        local _, _ = job_id, event
        view:write_all(data)
      end,
      stdout_buffered = false,
      stderr_buffered = false,
      stdin = "pipe",
    })
  end

  state.view = view
end

return M
