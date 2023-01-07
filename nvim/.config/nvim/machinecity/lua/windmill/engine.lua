-- todo: runner: terminal or luafile/luaeval/source
-- todo: limit output size

local M = {}

local jelly = require("infra.jellyfish")("windmill.engine", vim.log.levels.WARN)
local bufrename = require("infra.bufrename")
local ex = require("infra.ex")

local api = vim.api

local facts = {
  totem = "windmill",
  tty_height = 10,
  window_height = 10,
  keep_focus = true,
}

local state = {
  -- should only use one window
  win_id = nil,
  -- {bufnr: tick}
  changes = {},

  is_win_valid = function(self)
    if self.win_id == nil then return false end
    return api.nvim_win_is_valid(self.win_id)
  end,
  is_buf_changed = function(self, bufnr)
    local old_tick = self.changes[bufnr]
    local new_tick = api.nvim_buf_get_changedtick(bufnr)
    self.changes[bufnr] = new_tick
    return old_tick ~= new_tick
  end,
}

local TermView = (function()
  local count = 0

  local function resolve_win()
    if state:is_win_valid() then return state.win_id end

    ex("split")
    ex("wincmd", "J")
    local win_id = api.nvim_get_current_win()
    if facts.keep_focus then ex("wincmd", "p") end

    do
      -- same as nvim_open_win(style=minimal)
      local wo = vim.wo[win_id]
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
    api.nvim_win_set_height(win_id, facts.window_height)
    api.nvim_win_set_option(win_id, "winfixheight", true)
    -- todo: race condition
    state.win_id = win_id

    return win_id
  end

  return function()
    local view = {
      id = nil,
      bufnr = nil,
      chan = nil,

      -- process properties
      proc_chan = nil,
      exit_code = nil,

      write_all = function(self, data)
        -- todo: limited buffer size
        vim.fn.chansend(self.chan, data)
      end,
      deinit = function(self)
        vim.fn.chanclose(self.chan)
        self.chan = nil
        vim.fn.chanclose(self.proc_chan)
        self.proc_chan = nil
      end,
    }

    count = count + 1
    local view_id = count

    local bufnr
    do
      bufnr = api.nvim_create_buf(false, true)
      api.nvim_buf_set_var(bufnr, facts.totem, true)
      api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
      bufrename(bufnr, string.format("windmill://%s", view_id))
    end

    local win_id = resolve_win()
    api.nvim_win_set_buf(win_id, bufnr)

    local chan = api.nvim_open_term(bufnr, {
      on_input = function(event, term, _bufnr, data)
        local _, _, _ = event, term, _bufnr
        assert(view.proc_chan ~= nil)
        -- necessary for redirecting proc_chan.stdout -> libvterm.stdout -> proc.stdin
        -- eg, \27[6n
        vim.fn.chansend(view.proc_chan, data)
      end,
    })
    assert(chan ~= 0)

    view.id = view_id
    view.bufnr = bufnr
    view.chan = chan

    return view
  end
end)()

---@param cmd table
---@param cwd string|nil
M.run = function(cmd, cwd)
  assert(type(cmd) == "table" and #cmd > 0)
  cwd = cwd or vim.fn.getcwd()

  local view = TermView()

  jelly.debug("cmd=%s, cwd=%s", vim.inspect(cmd), cwd)

  -- todo: job management: max parallel jobs, run time, cancellation
  local proc_chan
  proc_chan = vim.fn.jobstart(cmd, {
    cwd = cwd,
    width = vim.o.columns,
    height = facts.tty_height,
    pty = true,
    on_exit = function(job_id, exit_code, event)
      local _, _ = job_id, event
      view.exit_code = exit_code
      jelly.debug("exited")
      view:deinit()
    end,
    on_stdout = function(job_id, data, event)
      local _, _ = job_id, event
      view:write_all(data)
      jelly.debug("stdout write: %s", vim.inspect(data))
    end,
    on_stderr = function(job_id, data, event)
      local _, _ = job_id, event
      view:write_all(data)
      jelly.debug("stderr write: %s", vim.inspect(data))
    end,
    -- enable buffer to reduce total wirte times
    stdout_buffered = false,
    stderr_buffered = false,
    -- enum{pipe,null}
    stdin = "pipe",
  })
  assert(proc_chan > 0)
  view.proc_chan = proc_chan
  jelly.debug("proc_chan: %d", proc_chan)
end

M.is_buf_changed = function(bufnr)
  return state:is_buf_changed(bufnr)
end

return M
