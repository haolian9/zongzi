-- design
-- * deinit will not clear the visual selection
-- * since there is only one state, no need to attach it to the WinClose

local api = vim.api

local jelly = require("infra.jellyfish")("squirrel.incsel")
local nuts = require("squirrel.nuts")

---@class squirrel.incsel.state
local state = {
  started = false,
  win_id = nil,
  bufnr = nil,
  ---@type TSNode[]
  path = nil,
}

function state:map(mode, lhs, rhs)
  assert(self.started)
  api.nvim_buf_set_keymap(self.bufnr, mode, lhs, "", {
    silent = true,
    noremap = true,
    callback = rhs,
  })
end

function state:unmap(mode, lhs)
  assert(self.started)
  api.nvim_buf_del_keymap(self.bufnr, mode, lhs)
end

function state:deinit()
  assert(self.started)
  local ok, err = pcall(function()
    self:unmap("v", "m")
    self:unmap("v", "n")
    self:unmap("v", [[<esc>]])
    self:unmap("n", [[<esc>]])
  end)
  self.started = false
  self.win_id = nil
  self.bufnr = nil
  self.path = nil
  jelly.info("squirrel.incsel deinited")
  if not ok then jelly.err("deinit failed with errors: %s", err) end
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
      nuts.vsel_node(self.win_id, next)
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
  nuts.vsel_node(self.win_id, next)
end

---@param win_id number
function state:init(win_id)
  assert(not self.started, "dirty incsel state, hasnt been deinited")
  assert(self.path == nil)

  self.win_id = win_id
  self.bufnr = api.nvim_win_get_buf(self.win_id)
  self.started = true
  self.path = {}
  table.insert(self.path, nuts.get_node_at_cursor(self.win_id))

  -- stylua: ignore
  local ok, err = pcall(function()
    assert(nuts.vsel_node(self.win_id, self.path[1]))
    self:map("v", "m", function() self:increase() end)
    self:map("v", "n", function() self:decrease() end)
    -- ModeChanged is not reliable, so we hijack the <esc>
    self:map("v", [[<esc>]], function() self:deinit() end)
    self:map("n", [[<esc>]], function() self:deinit() end)
  end)

  if not ok then
    self:deinit()
    error(err)
  end
end

return function()
  local win_id = api.nvim_get_current_win()

  if not state.started then
    state:init(win_id)
    return
  end

  if api.nvim_win_get_buf(win_id) ~= state.bufnr then
    state:deinit()
    state:init(win_id)
    return
  end
end
