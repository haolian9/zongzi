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

local jelly = require("infra.jellyfish")("gallop")
local tty = require("infra.tty")

local statemachine = require("gallop.statemachine")
local target_collectors = require("gallop.target_collectors")

local api = vim.api

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
  local function determine_chars(nchar, spare_chars)
    local chars
    if nchar ~= nil then
      chars = tty.read_chars(nchar)
      if #chars == 0 and spare_chars ~= nil then chars = spare_chars end
    else
      if spare_chars ~= nil then
        chars = spare_chars
      else
        chars = tty.read_chars(2)
      end
    end
    if #chars == 0 then return jelly.debug("canceled") end
    return chars
  end

  --forms: (3,nil), (nil,nil), (nil,foo), (3,foo)
  ---@param nchar? integer @nil=2
  ---@param spare_chars? string @ascii chars
  ---@return string? chars @nil if error occurs
  function M.words(nchar, spare_chars)
    local chars = determine_chars(nchar, spare_chars)
    if chars == nil then return end

    ---@diagnostic disable-next-line: unused-local
    statemachine(function(winid, bufnr, viewport) return target_collectors.word_head(bufnr, viewport, chars) end)

    return chars
  end

  --forms: (3,nil), (nil,nil), (nil,foo), (3,foo)
  ---@param nchar? integer @nil=2
  ---@param spare_chars? string @ascii chars
  ---@return string? chars @nil if error occurs
  function M.strings(nchar, spare_chars)
    local chars = determine_chars(nchar, spare_chars)
    if chars == nil then return end

    ---@diagnostic disable-next-line: unused-local
    statemachine(function(winid, bufnr, viewport) return target_collectors.string(bufnr, viewport, chars) end)

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
    local screen_col = api.nvim_win_call(winid, function() return vim.fn.virtcol(".") end)
    return target_collectors.cursorcolumn(viewport, winid, screen_col)
  end)
end

return M
