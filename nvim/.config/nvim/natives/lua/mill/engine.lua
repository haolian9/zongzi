local M = {}

local buflines = require("infra.buflines")
local bufrename = require("infra.bufrename")
local ctx = require("infra.ctx")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local jelly = require("infra.jellyfish")("mill.engine", "info")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local project = require("infra.project")
local strlib = require("infra.strlib")
local unsafe = require("infra.unsafe")
local wincursor = require("infra.wincursor")
local winsplit = require("infra.winsplit")

local facts = {
  tty_height = 5,
  window_height = 5,
  keep_focus = true,
}

---@class mill.engine.View
---@field bufnr      integer
---@field exit_code? integer @0=ok, >=1 failed
---@field write_all  fun(data: string[])

local TermView
do
  ---@class mill.engine.TermView : mill.engine.View
  ---@field term_chan integer @term chan
  ---@field proc_chan integer @spawned process chan
  local Impl = {}
  do
    Impl.__index = Impl

    ---@param data string[]
    function Impl:write_all(data)
      if self.term_chan == nil then return end
      vim.fn.chansend(self.term_chan, data)
    end

    function Impl:deinit()
      if self.proc_chan ~= nil then
        vim.fn.chanclose(self.proc_chan)
        self.proc_chan = nil
      end
      if self.term_chan ~= nil then
        vim.fn.chanclose(self.term_chan)
        self.term_chan = nil
      end
      if ni.buf_is_valid(self.bufnr) and prefer.bo(self.bufnr, "buftype") ~= "buftype" then --
        --dirty hack to unblock :qa
        unsafe.prepare_help_buffer(self.bufnr)
      end
    end
  end

  ---@param winid integer
  ---@return mill.engine.TermView
  function TermView(winid)
    local view = setmetatable({}, Impl)

    do
      local bufnr = ni.create_buf(false, true) --no ephemeral here
      prefer.bo(bufnr, "bufhidden", "wipe")
      bufrename(bufnr, string.format("mill://%d", bufnr))

      --user can abort the proc by closing TermView window
      ni.buf_attach(bufnr, false, { on_detach = function() view:deinit() end })

      view.bufnr = bufnr
    end

    prefer.wo(winid, "winfixbuf", false)
    ni.win_set_buf(winid, view.bufnr)
    prefer.wo(winid, "winfixbuf", true)

    do
      local term_chan = ni.open_term(view.bufnr, {
        on_input = function(_, _, _, data)
          assert(view.proc_chan ~= nil)
          -- necessary for redirecting proc_chan.stdout -> libvterm.stdout -> proc.stdin
          -- eg, \27[6n, <ctrl-c>
          vim.fn.chansend(view.proc_chan, data)
        end,
        --todo: resize win height, also rm '[term closed]' line
        -- on_exit = function() end
      })
      assert(term_chan ~= 0)
      wincursor.follow(winid, "bol")

      view.term_chan = term_chan
    end

    return view
  end
end

local SourceView
do
  ---@class mill.engine.SourceView: mill.engine.View
  ---@field winid integer
  local Impl = {}
  Impl.__index = Impl

  ---@param data string[]
  function Impl:write_all(data)
    assert(type(data) == "table")
    ctx.modifiable(self.bufnr, function() buflines.replaces(self.bufnr, -2, -1, data) end)
    prefer.bo(self.bufnr, "modified", false)
    wincursor.follow(self.winid, "bol")
  end

  function SourceView(winid)
    local bufnr = Ephemeral({ namepat = "mill://{bufnr}", modifiable = false })

    ni.win_set_buf(winid, bufnr)

    return setmetatable({ winid = winid, bufnr = bufnr }, Impl)
  end
end

local state = {}
do
  ---should use and reuse only one window
  ---@type integer?
  state.winid = nil

  ---last view
  ---@type mill.engine.TermView|mill.engine.SourceView|nil
  state.view = nil

  function state:is_win_valid()
    if self.winid == nil then return false end
    return ni.win_is_valid(self.winid)
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
    winid = ni.get_current_win()
    if facts.keep_focus then ex("wincmd", "p") end

    ni.win_set_height(winid, facts.window_height)
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
function M.spawn(cmd, cwd)
  assert(#cmd > 0)
  cwd = cwd or project.working_root()

  if state:has_one_running() then return jelly.warn("mill is still running, refuses to accept new work") end

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

function M.source(cmd)
  local parts = strlib.splits(cmd, " ", 1)
  assert(parts[1] == "source")

  local view ---@type mill.engine.SourceView
  do
    if not state:is_win_valid() then state.winid = open_win() end
    view = SourceView(state.winid)
    state.view = view
  end

  local ok, output = pcall(ni.cmd, { cmd = "source", args = { parts[2] } }, { output = true })
  assert(type(output), "string")
  view:write_all(strlib.splits(output, "\n"))
  view.exit_code = ok and 0 or 1
end

return M
