local M = {}

local ropes = require("string.buffer")
local new_table = require("table.new")

local ascii = require("infra.ascii")
local buflines = require("infra.buflines")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("gallop.target_collectors", "info")
local unsafe = require("infra.unsafe")
local utf8 = require("infra.utf8")

local facts = require("gallop.facts")

do
  -- for advancing the offset if the rest of a line starts with these chars
  local advance_matcher = vim.regex([[\v^[a-zA-Z0-9_]+]])

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
        if ascii.is_letter(string.sub(chars, 1, 1)) then rope:put([[\<]]) end
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

do
  ---credits: the shuangpin data is generated from https://github.com/mozillazg/pinyin-data/blob/v0.15.0/pinyin.txt

  local map

  ---@return {string: {string: true}}
  local function get_rune_shuangpin_map()
    if map then return map end

    map = new_table(0, 41923) --hardcode, depends on data
    --maybe: support fallback data file
    for line in io.lines(facts.shuangpin_file) do
      local pin = line:sub(1, #"ab")
      local rune = line:sub(#"ab " + 1)
      if map[rune] == nil then map[rune] = {} end
      map[rune][pin] = true
    end

    return map
  end

  ---@param bufnr integer
  ---@param lnum integer
  ---@param viewport gallop.Viewport
  ---@return string[]
  local function get_visible_line_runes(bufnr, lnum, viewport)
    --todo: *perf* do it in c to avoid string copying

    --WONTFIX: the line starts with broken utf8 rune
    assert(viewport.start_col == 0, "viewport has done some `zl`")

    local line
    do --assume all are utf8 runes in this line
      local stop = viewport.start_col + (viewport.stop_col - viewport.start_col) * 3
      line = assert(buflines.partial_line(bufnr, lnum, viewport.start_col, stop))
    end

    local runes = {}
    --ascii char takes one cell, utf8 rune takes two. accroding to fn.strdisplaywidth()
    local max_cells = viewport.stop_col - viewport.start_col
    local cell_count = 0
    for char in utf8.iterate(line, true) do
      table.insert(runes, char)
      local step = #char > 1 and 2 or 1
      --todo: tab may takes more cell; &tabstop
      --todo: setcellwidths() also
      --todo: step = nvim_strwidth(char) or fn.strdisplaywidth(char)
      cell_count = cell_count + step
      if cell_count == max_cells then break end
      if cell_count > max_cells then
        cell_count = cell_count - step
        table.remove(runes)
        break
      end
    end
    assert(cell_count <= max_cells)

    return runes
  end

  function M.report_shuangpin_data_stats()
    local stats = { total_lines = 0, total_runes = 0 }
    for _, pins in pairs(get_rune_shuangpin_map()) do
      stats.total_lines = stats.total_lines + #pins
      stats.total_runes = stats.total_runes + 1
    end
    jelly.info("shuangpin.data 收录汉字%s个，映射关系%s对", stats.total_runes, stats.total_lines)
  end

  ---自然码双拼。不支持补码
  ---@param bufnr integer
  ---@param viewport gallop.Viewport
  ---@param chars string @ascii only by design
  ---@return gallop.Target[], string? @(targets, pattern-being-used)
  function M.shuangpin(bufnr, viewport, chars) --
    assert(chars:match("^[a-z][a-z]$"), "invalid shuangpin")
    assert(viewport.start_col == 0, "viewport has done some `zl`")

    local rune_to_shuangpins = get_rune_shuangpin_map()
    local targets = {}

    --todo: batch get lines
    for lnum in itertools.range(viewport.start_line, viewport.stop_line) do
      local runes = get_visible_line_runes(bufnr, lnum, viewport)
      local offset = viewport.start_col

      for _, rune in ipairs(runes) do
        local col_start = offset
        local col_stop = col_start + #rune
        offset = offset + #rune
        if #rune < 2 then goto continue end

        local pins = rune_to_shuangpins[rune]
        if pins and pins[chars] then --
          table.insert(targets, { lnum = lnum, col_start = col_start, col_stop = col_stop, carrier = "buf", col_offset = 0 })
        end

        ::continue::
      end
    end

    return targets, chars
  end
end

return M
