local M = {}

local api = vim.api
local hop = require("hop")
local builtin_targets = require("hop.jump_target")
local hint = require("hop.hint")

local tty = require("infra.tty")
local vsel = require("infra.vsel")

local last_chars = nil

local function keymap(mode, lhs, rhs, opts)
  opts = opts or { noremap = true }
  api.nvim_set_keymap(mode, lhs, rhs, opts)
end

---@param chars string
local function repeatable_hop(chars)
  assert(chars ~= nil)
  last_chars = chars
  hop.hint_with(builtin_targets.jump_targets_by_scanning_lines(builtin_targets.regex_by_case_searching(chars, true, {})), hop.opts)
  vim.fn["repeat#set"](":lua require'foreign.hop'.repeats()\r")
end

---@param n number @n > 0
M.tty_chars = function(n)
  assert(n > 0)
  local chars = tty.read_chars(n)
  if #chars == 0 then return end
  repeatable_hop(chars)
end

M.vsel_chars = function()
  local chars = vsel.oneline_text()
  if chars == nil then return end
  repeatable_hop(chars)
end

M.cword_chars = function()
  local chars = vim.fn.expand("<cword>")
  if chars == nil then return end
  repeatable_hop(chars)
end

M.repeats = function()
  if last_chars == nil then return end
  repeatable_hop(last_chars)
end

-- true words, not keywords which respects `&iskeyword`
M.words = function(backward_only, cursorline_only)
  if cursorline_only == nil then cursorline_only = false end

  local opts
  do
    local overrides = {}
    overrides.current_line_only = cursorline_only
    if backward_only == nil then
    -- no direction
    elseif backward_only then
      overrides.direction = hint.HintDirection.BEFORE_CURSOR_LINE
    else
      overrides.direction = hint.HintDirection.AFTER_CURSOR_LINE
    end
    opts = setmetatable(overrides, { __index = hop.opts })
  end

  local targets_in_region = cursorline_only and builtin_targets.jump_targets_for_current_line or builtin_targets.jump_targets_by_scanning_lines

  -- todo: max number for each line
  -- search indifier
  local cells = builtin_targets.regex_by_searching([[[A-Za-z][A-Za-z0-9-_]\{2,}]])

  hop.hint_with(targets_in_region(cells), opts)
end

M.event_hi = function()
  api.nvim_set_hl(0, "HopNextKey", { ctermfg = 8, bold = true })
  api.nvim_set_hl(0, "HopNextKey1", { ctermfg = 8, bold = true })
  api.nvim_set_hl(0, "HopNextKey2", { ctermfg = 8, bold = true })
  api.nvim_set_hl(0, "HopUnmatched", { ctermfg = 243 })
end

M.setup = function()
  hop.setup({
    keys = "asdfjkl;ioweghqrupyzxcvbnm",
    teasing = false,
    case_insensitive = false,
    quit_key = { "<esc>", "<space>" },
  })

  api.nvim_create_autocmd("ColorScheme", { callback = M.event_hi })
  M.event_hi()

  keymap("n", [[sj]], "<cmd>lua require'foreign.hop'.words(false)<cr>")
  keymap("n", [[sk]], "<cmd>lua require'foreign.hop'.words(true)<cr>")
  keymap("n", [[s.]], "<cmd>lua require'foreign.hop'.words(nil, true)<cr>")
  keymap("n", [[s/]], "<cmd>lua require'foreign.hop'.tty_chars(5)<cr>")
  keymap("n", [[sw]], "<cmd>lua require'foreign.hop'.cword_chars(5)<cr>")
  keymap("n", [[sl]], "<cmd>lua require'hop'.hint_lines()<cr>")
  keymap("v", [[s]], ":lua require'foreign.hop'.vsel_chars()<cr>")
end

return M
