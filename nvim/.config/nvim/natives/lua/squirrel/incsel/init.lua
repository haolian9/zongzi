-- design
-- * deinit will not clear the visual selection
-- * since there is only one state, no need to attach it to the WinClose

local M = {}

local ctx = require("infra.ctx")
local jelly = require("infra.jellyfish")("squirrel.incsel")
local bufmap = require("infra.keymap.buffer")
local ni = require("infra.ni")

local startpoints = require("squirrel.incsel.startpoints")
local nuts = require("squirrel.nuts")

---@class squirrel.incsel.state
local state = {}
do
  state.started = false
  state.winid = nil
  state.bufnr = nil
  ---@type TSNode[]
  state.path = nil
  state.attached = false --flag for nvim_buf_attach
  state.submode_deinit = nil

  function state:deinit()
    assert(self.started)
    do -- cleanup submode keymaps
      self.submode_deinit()
      self.submode_deinit = nil
    end
    do -- cleanup state
      self.started = false
      self.winid = nil
      self.bufnr = nil
      self.path = nil
    end
    jelly.info("squirrel.incsel deinited")
  end

  function state:increase()
    assert(self.started)
    local start = self.path[#self.path]
    local next = start:parent()
    while next ~= nil do
      local parent = next:parent()
      -- tip as highest node, not root
      if not nuts.same_range(next, start) and parent ~= nil then
        table.insert(self.path, next)
        nuts.vsel_node(self.winid, next)
        return
      end
      next = parent
    end
    jelly.info("reached tip node")
  end

  function state:decrease()
    assert(self.started)
    -- back to start node, do nothing
    if #self.path == 1 then return jelly.info("reached start node") end

    table.remove(self.path, #self.path)
    local next = assert(self.path[#self.path])
    nuts.vsel_node(self.winid, next)
  end

  ---@param winid number
  ---@param startpoint_resolver fun(winid: number):TSNode
  function state:init(winid, startpoint_resolver)
    assert(not self.started, "dirty incsel state, hasnt been deinited")
    assert(self.path == nil)

    do -- prepare state
      self.winid = winid
      self.bufnr = ni.win_get_buf(self.winid)
      self.started = true
      self.path = {}
      table.insert(self.path, startpoint_resolver(self.winid))
    end

    assert(nuts.vsel_node(self.winid, self.path[1]))

    do -- set keymaps
      self.submode_deinit = ctx.bufsubmode(self.bufnr, {
        { "x", "m" },
        { "x", "n" },
        { "x", "<esc>" },
        { "n", "<esc>" },
        { "x", "<c-[>" },
        { "n", "<c-[>" },
      })

      local bm = bufmap.wraps(self.bufnr)
      bm.x("m", function() self:increase() end)
      bm.x("n", function() self:decrease() end)

      -- ModeChanged is not reliable, so we hijack the <esc>
      bm.x("<esc>", function() self:deinit() end)
      bm.n("<esc>", function() self:deinit() end)
      bm.x("<c-[>", function() self:deinit() end)
      bm.n("<c-[>", function() self:deinit() end)
    end

    --it's possible to call state:init() multiple times but the buffer has no changes even once
    if not self.attached then
      self.attached = true
      assert(ni.buf_attach(self.bufnr, false, {
        on_lines = function()
          if self.started then self:deinit() end
          assert(self.attached)
          self.attached = false
          return true
        end,
      }))
    end
  end
end

function M.n()
  local pointer = startpoints.n()
  local winid = ni.get_current_win()

  if not state.started then
    state:init(winid, pointer)
    return
  end

  if ni.win_get_buf(winid) ~= state.bufnr then
    state:deinit()
    state:init(winid, pointer)
    return
  end
end

function M.m(filetype)
  local winid = ni.get_current_win()
  local pointer = startpoints.m(filetype)

  if not state.started then
    state:init(winid, pointer)
    return
  end

  if ni.win_get_buf(winid) ~= state.bufnr then
    state:deinit()
    state:init(winid, pointer)
    return
  end
end

return M
