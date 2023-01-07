-- design choices
-- * only buffer for each fpath
-- * only one window for each tab

local M = {}

local api = vim.api
local bufrename = require("infra.bufrename")
local ex = require("infra.ex")

---@class canvas
local canvas = {
  -- {fpath: (bufnr, {tabpage: win_id})}
  --
  ---@type { [string]: {bufnr: number, tab_win: table<number, number>} }
  store = {},

  ---@param self canvas
  ---@return number|nil,number|nil @bufnr,win_id
  get = function(self, fpath, tabpage)
    local held = self.store[fpath]
    if held == nil then return end

    if not api.nvim_buf_is_valid(held.bufnr) then
      self.store[fpath] = nil
      return
    end

    local held_win = held.tab_win[tabpage]
    if held_win == nil or not api.nvim_win_is_valid(held_win) then
      held.tab_win[tabpage] = nil
      return held.bufnr, nil
    end

    return held.bufnr, held_win
  end,

  ---@param self canvas
  set = function(self, fpath, bufnr, tabpage, win_id)
    local held = self.store[fpath]
    if held == nil then
      self.store[fpath] = { bufnr = bufnr, tab_win = { [tabpage] = win_id } }
      return
    end

    assert(held.bufnr == bufnr)

    local held_win = held.tab_win[tabpage]
    if held_win == nil then
      held.tab_win[tabpage] = win_id
      return
    end

    if held_win == win_id then return end

    assert(not api.nvim_win_is_valid(held_win))
    held.tab_win[tabpage] = win_id
  end,
}

local function tail(bufnr, win_id, fpath)
  assert(bufnr and win_id and fpath)
  local height = math.max(100, vim.fn.winheight(win_id))
  local scrollback = math.floor(height / 2)

  api.nvim_create_autocmd("TermOpen", {
    buffer = bufnr,
    once = true,
    callback = function()
      api.nvim_buf_set_option(bufnr, "scrollback", scrollback)
    end,
  })

  local job
  do
    local cmd = { "tail", "-n", height + scrollback, "-f", fpath }
    job = vim.fn.termopen(cmd, { stderr_buffered = false, stdout_buffered = false, stdin = "" })
  end

  -- cleanup the process and buffer
  api.nvim_create_autocmd("WinClosed", {
    callback = function(args)
      if win_id ~= tonumber(args.match) then return end
      vim.fn.jobstop(job)
      api.nvim_buf_delete(bufnr, { force = true })
      return true
    end,
  })

  bufrename(bufnr, string.format("tail://%s", fpath))
  ex("normal", "G")
end

function M.split_below(fpath)
  assert(fpath ~= nil)

  local tabpage = api.nvim_get_current_tabpage()

  local bufnr, win_id
  do
    local held_bufnr, held_win_id = canvas:get(fpath, tabpage)
    if held_bufnr and held_win_id then return end
    bufnr = held_bufnr or api.nvim_create_buf(false, true)
    if held_win_id ~= nil then
      win_id = held_win_id
    else
      ex("rightbelow split")
      win_id = api.nvim_get_current_win()
      api.nvim_win_set_height(win_id, 10)
      api.nvim_win_set_option(win_id, "winfixheight", true)
    end
  end

  api.nvim_win_set_buf(win_id, bufnr)
  canvas:set(fpath, bufnr, tabpage, win_id)
  tail(bufnr, win_id, fpath)
end

return M
