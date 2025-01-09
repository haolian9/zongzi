-- about the name
--
-- whoa. nice car, man.
-- yeah. it gets me from A to B.
--
-- oh, darn. all this horsepower and no room to gallop.
--

-- known limits
-- * not work in a gui frontend of neovim due to tty:read()
--
-- undefined behaviors
-- * &foldenabled

local M = {}

local ctx = require("infra.ctx")
local jelly = require("infra.jellyfish")("gallop")
local repeats = require("infra.repeats")
local tty = require("infra.tty")

local statemachine = require("gallop.statemachine")
local target_collectors = require("gallop.target_collectors")

do
  --usecases
  --* (3,   nil) ask 3 chars, if it's been canceled, exit
  --* (nil, nil) ask 2 chars, if it's been canceled, exit
  --* (nil, foo) no asking, use 'foo' directly
  --* (3,   foo) ask 3 chars, if it's been canceled, use 'foo' directly
  --
  ---@param nchar? integer @nil=2
  ---@param spare_chars? string @ascii chars
  ---@return string?
  local function await_input_chars(nchar, spare_chars)
    local chars
    if nchar ~= nil then
      chars = tty.read_chars(nchar)
      if chars == "" and spare_chars ~= nil then chars = spare_chars end
    else
      if spare_chars ~= nil then
        chars = spare_chars
      else
        chars = tty.read_chars(2)
      end
    end
    if chars == "" then return jelly.debug("canceled") end
    return chars
  end

  ---search within the visible region of current window
  ---@param pattern string @vim very magic regex pattern
  local function remember_charsearch(pattern)
    local function next() vim.fn.search(pattern, "s", vim.fn.line("w$")) end
    local function prev() vim.fn.search(pattern, "bs", vim.fn.line("w0")) end

    repeats.remember_charsearch(next, prev)
  end

  --forms: (3,nil), (nil,nil), (nil,foo), (3,foo)
  ---@param nchar? integer @nil=2
  ---@param spare_chars? string @ascii chars
  ---@param enable_repeat? boolean @nil=false
  ---@return string? chars @nil if error occurs
  function M.words(nchar, spare_chars, enable_repeat)
    if enable_repeat == nil then enable_repeat = false end

    local chars = await_input_chars(nchar, spare_chars)
    if chars == nil then return end

    local pattern

    ---@diagnostic disable-next-line: unused-local
    statemachine(function(winid, bufnr, viewport)
      local targets
      targets, pattern = target_collectors.word_head(bufnr, viewport, chars)
      return targets, pattern
    end)

    if enable_repeat then remember_charsearch(pattern) end

    return chars
  end

  --forms: (3,nil), (nil,nil), (nil,foo), (3,foo)
  ---@param nchar? integer @nil=2
  ---@param spare_chars? string @ascii chars
  ---@param enable_repeat? boolean @nil=false
  ---@return string? chars @nil if error occurs
  function M.strings(nchar, spare_chars, enable_repeat)
    if enable_repeat == nil then enable_repeat = false end

    local chars = await_input_chars(nchar, spare_chars)
    if chars == nil then return end

    local pattern

    ---@diagnostic disable-next-line: unused-local
    statemachine(function(winid, bufnr, viewport)
      local targets
      targets, pattern = target_collectors.string(bufnr, viewport, chars)
      return targets, pattern
    end)

    if enable_repeat then remember_charsearch(pattern) end

    return chars
  end
end

function M.lines()
  ---@diagnostic disable-next-line: unused-local
  statemachine(function(winid, bufnr, viewport) return target_collectors.line_head(viewport) end)
end

function M.cursorcolumn()
  statemachine(function(winid, bufnr, viewport)
    local _ = bufnr
    ---@diagnostic disable-next-line: redundant-return-value
    local screen_col = ctx.win(winid, function() return vim.fn.virtcol(".") - viewport.start_col end)
    return target_collectors.cursorcolumn(viewport, screen_col)
  end)
end

return M
