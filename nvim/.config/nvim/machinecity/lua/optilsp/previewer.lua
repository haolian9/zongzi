local M = {}

local api = vim.api
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("optilsp.previewer")
local bufrename = require("infra.bufrename")

local state = {
  bufnr = nil,
  win_id = nil,

  ---@param self table
  is_buf_valid = function(self)
    return self.bufnr ~= nil and api.nvim_buf_is_valid(self.bufnr)
  end,

  ---@param self table
  is_win_valid = function(self)
    return self.win_id ~= nil and api.nvim_win_is_valid(self.win_id)
  end,
}

local facts = {
  bufname = "pum://preview",
}

local function interpret_event(event)
  -- screen/editor level
  local row, col
  do
    local pum_row_start = event.row
    local pum_col_end = event.col + event.width
    row = pum_row_start
    col = pum_col_end + 1
  end

  local function nothing()
    return {}, 0, 0, 0, 0
  end

  -- have enough room
  local compitem = fn.get(event, "completed_item", "user_data", "nvim", "lsp", "completion_item")
  if compitem == nil then return nothing() end

  -- todo: respect kind

  local lines = {}
  local sepline = "-----"
  local need_sepline = false
  local width = 1

  local deprecated = compitem["deprecated"] == true
  if deprecated then
    table.insert(lines, "deprecated")
    if width < 10 then width = 10 end
    need_sepline = true
  end

  local labeldetail = fn.get(compitem, "labelDetails", "detail")
  if labeldetail ~= nil then
    if need_sepline then table.insert(lines, sepline) end
    for line in fn.split_iter(labeldetail, "\n") do
      table.insert(lines, line)
      if width < #line then width = #line end
    end
    need_sepline = true
  end

  -- maybe: handle markdown
  local docstr = fn.get(compitem, "documentation", "value")
  if docstr ~= nil then
    if need_sepline then table.insert(lines, sepline) end
    for line in fn.split_iter(docstr, "\n") do
      table.insert(lines, line)
      if width < #line then width = #line end
    end
    need_sepline = true
  end

  do
    if #lines == 0 then return nothing() end
    local empty = true
    for _, line in ipairs(lines) do
      if #line > 0 then
        empty = false
        break
      end
    end
    if empty then return nothing() end
  end

  -- add paddings
  table.insert(lines, 1, "")
  table.insert(lines, "")

  assert(width > 0)
  -- todo: max width, wrap
  return lines, width, #lines, row, col
end

local function show_preview(event)
  if not state:is_buf_valid() then
    state.bufnr = api.nvim_create_buf(false, true)
    bufrename(state.bufnr, facts.bufname)
    api.nvim_buf_set_option(state.bufnr, "bufhidden", "unload")
  end

  -- todo: win.wrap
  -- todo: width regarding to win-width
  local lines, width, height, row, col = interpret_event(event)
  if #lines == 0 then return end

  -- vim.schedule exists for textlock
  vim.schedule(function()
    local ok, err = pcall(api.nvim_buf_set_lines, state.bufnr, 0, -1, false, lines)
    if not ok then jelly.warn(err) end

    if state:is_win_valid() then
      api.nvim_win_set_height(state.win_id, #lines)
      api.nvim_win_set_width(state.win_id, width)
    else
      -- stylua: ignore
      state.win_id = api.nvim_open_win(state.bufnr, false, {
        style = "minimal", noautocmd = true, relative = "editor",
        width = width, height = height, row = row, col = col,
      })
    end
  end)
end

local function hide_preview()
  if not state:is_win_valid() then return end
  api.nvim_win_close(state.win_id, true)
  state.win_id = nil
end

function M.setup()
  vim.api.nvim_create_autocmd("CompleteChanged", {
    callback = function()
      show_preview(vim.v.event)
    end,
  })

  vim.api.nvim_create_autocmd("CompleteDone", {
    callback = function()
      if vim.fn.pumvisible() == 1 then return end
      hide_preview()
    end,
  })
end

return M
