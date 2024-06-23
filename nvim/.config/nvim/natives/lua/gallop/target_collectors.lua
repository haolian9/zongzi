local M = {}

local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("gallop.target_collectors", "info")
local unsafe = require("infra.unsafe")

local ropes = require("string.buffer")

do
  -- for advancing the offset if the rest of a line starts with these chars
  local advance_matcher = vim.regex([[\v^[^a-zA-Z0-9_]+]])

  ---@param bufnr number
  ---@param viewport gallop.Viewport
  ---@param target_regex vim.Regex
  ---@return gallop.Target[]
  local function collect(bufnr, viewport, target_regex)
    local targets = {}
    local lineslen = itertools.todict(unsafe.linelen_iter(bufnr, itertools.range(viewport.start_line, viewport.stop_line)))

    for lnum in itertools.range(viewport.start_line, viewport.stop_line) do
      local offset = viewport.start_col
      local eol = math.min(viewport.stop_col, lineslen[lnum])
      while offset < eol do
        local col_start, col_stop
        do -- match next target
          local rel_start, rel_stop = target_regex:match_line(bufnr, lnum, offset, eol)
          if rel_start == nil then break end
          col_start = rel_start + offset
          col_stop = rel_stop + offset
        end
        do -- advance offset
          local adv_start, adv_stop = advance_matcher:match_line(bufnr, lnum, col_stop, eol)
          if adv_start ~= nil then
            offset = adv_stop + col_stop
          else
            offset = col_stop
          end
          assert(offset >= col_stop)
        end
        table.insert(targets, { lnum = lnum, col_start = col_start, col_stop = col_stop, carrier = "buf", col_offset = 0 })
      end
    end

    return targets
  end

  do
    local rope = ropes.new()

    ---@param bufnr integer
    ---@param viewport gallop.Viewport
    ---@param chars string @ascii only by design
    ---@return gallop.Target[], string? @(targets, pattern-being-used)
    function M.word_head(bufnr, viewport, chars)
      local pattern
      do
        rope:put([[\M]])
        --&smartcase
        rope:put(string.find(chars, "%u") and [[\C]] or [[\c]])
        --word bound
        local c0 = string.byte(string.sub(chars, 1, 1))
        if (c0 >= 97 and c0 <= 122) or (c0 >= 65 and c0 <= 90) then rope:put([[\<]]) end
        rope:put(chars)

        pattern = rope:get()
        jelly.debug("pattern='%s'", pattern)
      end

      return collect(bufnr, viewport, vim.regex(pattern)), pattern
    end
  end

  do
    local rope = ropes.new()

    ---@param bufnr integer
    ---@param viewport gallop.Viewport
    ---@param chars string @ascii only by design
    ---@return gallop.Target[], string? @(targets, pattern-being-used)
    function M.string(bufnr, viewport, chars)
      local pattern
      do
        rope:put([[\M]])
        --&smartcase
        rope:put(string.find(chars, "%u") and [[\C]] or [[\c]])
        rope:put(chars)

        pattern = rope:get()
        jelly.debug("pattern='%s'", pattern)
      end

      return collect(bufnr, viewport, vim.regex(pattern)), pattern
    end
  end
end

---@param viewport gallop.Viewport
---@return gallop.Target[], string? @(targets, pattern-being-used)
function M.line_head(viewport)
  local targets = {}
  for lnum in itertools.range(viewport.start_line, viewport.stop_line) do
    table.insert(targets, { lnum = lnum, col_start = 0, col_stop = 1, carrier = "buf", col_offset = 0 })
  end
  return targets, nil
end

---@param viewport gallop.Viewport
---@param screen_col integer @see virtcol
---@return gallop.Target[], string? @(targets, pattern-being-used)
function M.cursorcolumn(viewport, screen_col)
  local offset = viewport.start_col
  local start = screen_col
  local stop = screen_col + 1

  local targets = {}
  for lnum in itertools.range(viewport.start_line, viewport.stop_line) do
    table.insert(targets, { lnum = lnum, col_start = start, col_stop = stop, carrier = "win", col_offset = offset })
  end
  return targets, nil
end

return M
