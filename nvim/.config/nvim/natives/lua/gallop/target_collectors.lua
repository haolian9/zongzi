local M = {}

local ropes = require("string.buffer")
local new_table = require("table.new")

local ascii = require("infra.ascii")
local buflines = require("infra.buflines")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("gallop.target_collectors", "info")
local logging = require("infra.logging")
local unsafe = require("infra.unsafe")
local utf8 = require("infra.utf8")

local facts = require("gallop.facts")

local log = logging.newlogger("gallop.target_collectors", "info")

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
    local rope = ropes.new(32)

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
        if string.find(chars, "^%a") then rope:put([[\<]]) end
        rope:put(chars)

        pattern = rope:get()
        jelly.debug("pattern='%s'", pattern)
      end

      return collect(bufnr, viewport, vim.regex(pattern)), pattern
    end
  end

  do
    local rope = ropes.new(32)

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
  ---@return integer start_col_offset 0-based, for viewport.start_col
  ---@return string[] runes
  local function get_visible_line_runes(bufnr, lnum, viewport)
    --todo: *perf* do it in c to avoid string copying

    local line
    do
      ---view.start_col stands for the number of cells scrolled for utf8 rune filled line
      ---rather than byte offset,
      local start = 0
      --assume all are utf8 runes in this line
      local stop = 0
      stop = stop + viewport.start_col * 3 --scrolled length
      stop = stop + (viewport.stop_col - viewport.start_col) * 3 --current screen

      line = assert(buflines.partial_line(bufnr, lnum, start, stop))
      log.debug("line #%s [%s]", #line, line)
    end

    local iter = utf8.iterate(line, 1, false)

    local skipped_bytes = 0
    do --skip scrolled cells
      local scrolled_cell_remain = viewport.start_col
      for _ = 1, viewport.start_col do
        local char = iter()
        if char == nil then goto continue end
        skipped_bytes = skipped_bytes + #char
        local step = #char > 1 and 2 or 1
        scrolled_cell_remain = scrolled_cell_remain - step
        if scrolled_cell_remain < 1 then break end
        ::continue::
      end
    end

    local runes = {}
    do
      --ascii char takes one cell, utf8 rune takes two
      local max_cells = viewport.stop_col - viewport.start_col
      log.debug("viewport=%s line_soffset=%s max_cells=%s", viewport, line_soffset, max_cells)
      local cell_count = 0
      for char in iter do
        table.insert(runes, char)
        --todo: tab may takes more cell; &tabstop; setcellwidths() also
        --      * tried nvim_strwidth(char), which makes no difference in my test.
        local step = #char > 1 and 2 or 1
        cell_count = cell_count + step
        if cell_count >= max_cells then break end
      end
      log.debug("runes #%s %s", #runes, runes)
    end

    return skipped_bytes - viewport.start_col, runes
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

    local rune_to_shuangpins = get_rune_shuangpin_map()
    local targets = {}

    --todo: batch get lines
    for lnum in itertools.range(viewport.start_line, viewport.stop_line) do
      local start_col_offset, runes = get_visible_line_runes(bufnr, lnum, viewport)
      local offset = viewport.start_col + start_col_offset

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
