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
local ni = require("infra.ni")
local repeats = require("infra.repeats")
local tty = require("infra.tty")
local InputHinter = require("infra.tty.InputHinter")
local wincursor = require("infra.wincursor")

local Gallop = require("gallop.Gallop")
local target_collectors = require("gallop.target_collectors")

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
    chars = tty.read_chars(nchar, InputHinter("🐎", nchar))
    if chars == "" and spare_chars ~= nil then chars = spare_chars end
  else
    if spare_chars ~= nil then
      chars = spare_chars
    else
      chars = tty.read_chars(2, InputHinter("🐎", 2))
    end
  end
  if chars == "" then return jelly.debug("canceled") end
  return chars
end

do
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
    Gallop.new(function(winid, bufnr, viewport)
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
    Gallop.new(function(winid, bufnr, viewport)
      local targets
      targets, pattern = target_collectors.string(bufnr, viewport, chars)
      return targets, pattern
    end)

    if enable_repeat then remember_charsearch(pattern) end

    return chars
  end
end

do
  ---@param winid integer
  ---@param targets gallop.Target[]
  local function remember_charsearch(winid, targets)
    local idx = 1
    do --find out chosen target index
      local cursor = wincursor.position(winid)
      for i, target in ipairs(targets) do
        if target.lnum == cursor.lnum and target.col_start == cursor.col then
          idx = i
          break
        end
      end
    end

    local function jump(x)
      if winid ~= ni.get_current_win() then return jelly.warn("not the same window to gallop.shuangpin") end
      --maybe: no-op after changedtick changed
      if idx == x then return end
      idx = x
      Gallop.goto_target(winid, targets[idx])
    end

    local function next() jump(math.min(idx + 1, #targets)) end
    local function prev() jump(math.max(idx - 1, 1)) end

    repeats.remember_charsearch(next, prev)
  end

  ---@param spare_chars? string @ascii chars
  ---@param enable_repeat? boolean @nil=false
  ---@return string? chars @nil if error occurs
  function M.shuangpin(spare_chars, enable_repeat)
    if enable_repeat == nil then enable_repeat = false end

    local chars = await_input_chars(2, spare_chars)
    if chars == nil then return end
    if #chars ~= 2 then return jelly.warn("双拼!") end

    --@type gallop.Target[], string?
    local targets, pattern

    Gallop.new(function(_, bufnr, viewport)
      targets, pattern = target_collectors.shuangpin(bufnr, viewport, chars)
      return targets, pattern
    end)

    --todo: honor enable_repeat
    if enable_repeat and #targets > 1 then remember_charsearch(ni.get_current_win(), targets) end

    return chars
  end
end

function M.lines()
  ---@diagnostic disable-next-line: unused-local
  Gallop.new(function(winid, bufnr, viewport) return target_collectors.line_head(viewport) end)
end

function M.cursorcolumn()
  Gallop.new(function(winid, bufnr, viewport)
    local _ = bufnr
    ---@diagnostic disable-next-line: redundant-return-value
    local screen_col = ctx.win(winid, function() return vim.fn.virtcol(".") - viewport.start_col end)
    return target_collectors.cursorcolumn(viewport, screen_col)
  end)
end

return M
