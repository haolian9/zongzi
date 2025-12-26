local M = {}

---movititation: (in my personal opionion)
---* no strict_indexing param
---   * nvim_buf_get/set_lines makes no sense, it'd be false here always
---   * actually strict_indexing=true had bitten me several times with no reason, i consulted the matrix nvim room and got no answer
---   * so it'd be better to just omit this param
---* intuitive, simple responsibility api
---   * nvim_buf_get/set_lines is not designed for human, with too many param combination

local ropes = require("string.buffer")

local itertools = require("infra.itertools")
local its = require("infra.its")
local jelly = require("infra.jellyfish")("infra.buflines", "debug")
local ni = require("infra.ni")
local unsafe = require("infra.unsafe")

---@param start? integer @0-based, inclusive
---@param stop? integer @0-based, exclusive
---@return integer @start, 0-based, inclusive
---@return integer @stop, 0-based, exclusive
local function resolve_relative_range(start, stop)
  if start == nil and stop == nil then return 0, -1 end
  if start ~= nil and stop == nil then return 0, start end
  assert(start and stop)
  return start, stop
end

---notes:
---* start -1=high
---* stop  -1=high+1
---@param bufnr integer
---@param start? integer @0-based, inclusive
---@param stop? integer @0-based, exclusive
---@return integer @start, 0-based, inclusive
---@return integer @stop, 0-based, exclusive
local function resolve_absolute_range(bufnr, start, stop)
  local high = M.high(bufnr)
  --todo: high=1, start=-2, stop=-2

  if start == nil and stop == nil then return 0, high + 1 end

  if start ~= nil and stop == nil then
    start, stop = 0, start
  end

  assert(start and stop)
  if start < 0 then start = high + (start + 1) end
  assert(start >= 0, "illegal start value")
  if stop < 0 then stop = high + (stop + 1) + 1 end
  assert(stop >= 0, "illegal stop value")

  return start, stop
end

do
  ---@param bufnr integer
  ---@return integer
  function M.count(bufnr) return ni.buf_line_count(bufnr) end

  ---@param bufnr integer
  ---@return integer @>=0
  function M.high(bufnr)
    local count = M.count(bufnr) - 1
    return math.max(0, count)
  end

  ---including blank lines
  ---@param bufnr integer
  ---@param wrap_width integer
  ---@return integer
  function M.wrapped_count(bufnr, wrap_width)
    local count = 0
    for _, len in unsafe.linelen_iter(bufnr, itertools.range(M.count(bufnr))) do
      if len == 0 then
        count = count + 1
      else
        count = count + math.ceil(len / wrap_width)
      end
    end
    return count
  end
end

do
  ---@param bufnr integer
  ---@param start_lnum? integer @0-based, inclusive
  ---@param stop_lnum? integer @0-based, exclusive
  ---@return string[]
  function M.lines(bufnr, start_lnum, stop_lnum)
    start_lnum, stop_lnum = resolve_relative_range(start_lnum, stop_lnum)

    return ni.buf_get_lines(bufnr, start_lnum, stop_lnum, false)
  end

  ---@param bufnr integer
  ---@param lnum integer @0-based, accepts -1
  ---@return string?
  function M.line(bufnr, lnum)
    local start_lnum, stop_lnum
    if lnum >= 0 then -- 0 (0, 1)
      start_lnum, stop_lnum = lnum, lnum + 1
    else -- -1 (-2,-1)
      start_lnum, stop_lnum = lnum - 1, lnum
    end
    return ni.buf_get_lines(bufnr, start_lnum, stop_lnum, false)[1]
  end
end

do
  local rope = ropes.new()

  ---@param bufnr integer
  ---@param start_lnum? integer @0-based, inclusive
  ---@param stop_lnum? integer @0-based, exclusive
  ---@return string
  function M.joined(bufnr, start_lnum, stop_lnum)
    local range = itertools.range(resolve_absolute_range(bufnr, start_lnum, stop_lnum))

    for ptr, len in unsafe.lineref_iter(bufnr, range) do
      rope:put("\n")
      rope:putcdata(ptr, len)
    end
    rope:skip(#"\n")

    return rope:get()
  end
end

do
  ---@param bufnr integer
  ---@param lnum integer @0-based
  ---@param start_col integer @0-based, inclusive
  ---@param stop_col integer @0-based, exclusive
  ---@return string?
  function M.partial_line(bufnr, lnum, start_col, stop_col)
    local lines = ni.buf_get_text(bufnr, lnum, start_col, lnum, stop_col, {})
    assert(#lines <= 1)
    return lines[1]
  end
end

do
  ---@param bufnr integer
  ---@param start_lnum? integer @0-based, inclusive
  ---@param stop_lnum? integer @0-based, exclusive
  ---@return fun():string?,integer? @iter(line,lnum)
  function M.iter(bufnr, start_lnum, stop_lnum)
    local range = itertools.range(resolve_absolute_range(bufnr, start_lnum, stop_lnum))
    return itertools.map(range, function(lnum) return M.line(bufnr, lnum), lnum end)
  end

  ---@param bufnr integer
  ---@return fun(): string?,integer? @iter(line,lnum)
  function M.iter_reversed(bufnr)
    --todo: support start_lnum, stop_lnum
    local range = itertools.range(M.high(bufnr), 0 - 1, -1)
    return itertools.map(range, function(lnum) return M.line(bufnr, lnum), lnum end)
  end
end

do
  ---@param bufnr integer
  ---@param regex vim.Regex
  ---@param negative boolean
  ---@param start_lnum? integer @0-based, inclusive
  ---@param stop_lnum? integer @0-based, exclusive
  ---@return fun(): string?,integer? @iter(line,lnum)
  local function main(bufnr, regex, negative, start_lnum, stop_lnum)
    local iter = its(itertools.range(resolve_absolute_range(bufnr, start_lnum, stop_lnum)))

    if negative then
      iter:filter(function(lnum) return regex:match_line(bufnr, lnum) == nil end)
    else
      iter:filter(function(lnum) return regex:match_line(bufnr, lnum) ~= nil end)
    end

    iter:map(function(lnum)
      local line = M.lines(bufnr, lnum, lnum + 1)[1]
      ---@diagnostic disable-next-line: redundant-return-value
      return line, lnum
    end)

    return iter:unwrap()
  end

  ---@param bufnr integer
  ---@param regex vim.Regex
  ---@param start_lnum? integer @0-based, inclusive
  ---@param stop_lnum? integer @0-based, exclusive
  ---@return fun(): string?,integer? @iter(line,lnum)
  function M.iter_matched(bufnr, regex, start_lnum, stop_lnum) return main(bufnr, regex, false, start_lnum, stop_lnum) end

  ---@param bufnr integer
  ---@param regex vim.Regex
  ---@param start_lnum? integer @0-based, inclusive
  ---@param stop_lnum? integer @0-based, exclusive
  ---@return fun(): string?,integer? @iter(line,lnum)
  function M.iter_unmatched(bufnr, regex, start_lnum, stop_lnum) return main(bufnr, regex, true, start_lnum, stop_lnum) end
end

do
  ---@param bufnr integer
  ---@param start_lnum integer @0-based, inclusive
  ---@param stop_lnum integer @0-based, exclusive
  ---@param lines string[]
  function M.sets(bufnr, start_lnum, stop_lnum, lines)
    local ok, err = xpcall(ni.buf_set_lines, debug.traceback, bufnr, start_lnum, stop_lnum, false, lines)
    if not ok then jelly.fatal("RuntimeError", "lines: '%s'; err: %s", lines, err) end
  end

  ---@param bufnr integer
  ---@param lnum integer @0-based, inclusive
  ---@param line string
  function M.replace(bufnr, lnum, line)
    local start_lnum, stop_lnum
    if lnum >= 0 then
      start_lnum, stop_lnum = lnum, lnum + 1
    else
      start_lnum, stop_lnum = lnum - 1, lnum
    end
    M.sets(bufnr, start_lnum, stop_lnum, { line })
  end

  ---@param bufnr integer
  ---@param start_lnum integer @0-based, inclusive, could be negative
  ---@param stop_lnum integer @0-based, exclusive, could be negative
  ---@param lines string[]
  function M.replaces(bufnr, start_lnum, stop_lnum, lines)
    start_lnum, stop_lnum = resolve_relative_range(start_lnum, stop_lnum)
    M.sets(bufnr, start_lnum, stop_lnum, lines)
  end

  ---@param bufnr integer
  ---@param lines string[]
  function M.replaces_all(bufnr, lines) M.sets(bufnr, 0, -1, lines) end

  do
    local function resolve_range(lnum)
      if lnum >= 0 then
        return lnum + 1, lnum + 1
      else
        return lnum, lnum
      end
    end

    ---@param bufnr integer
    ---@param lnum integer @0-based, exclusive; accepts negative
    ---@param line string
    function M.append(bufnr, lnum, line)
      local start_lnum, stop_lnum = resolve_range(lnum)
      M.sets(bufnr, start_lnum, stop_lnum, { line })
    end

    ---@param bufnr integer
    ---@param lnum integer @0-based, exclusive
    ---@param lines string[]
    function M.appends(bufnr, lnum, lines)
      local start_lnum, stop_lnum = resolve_range(lnum)
      M.sets(bufnr, start_lnum, stop_lnum, lines)
    end
  end

  do
    local function resolve_range(lnum)
      if lnum >= 0 then
        return lnum, lnum
      else
        return lnum - 1, lnum - 1
      end
    end

    ---@param bufnr integer
    ---@param lnum integer @0-based, exclusive
    ---@param line string
    function M.prepend(bufnr, lnum, line)
      local start_lnum, stop_lnum = resolve_range(lnum)
      M.sets(bufnr, start_lnum, stop_lnum, { line })
    end

    ---@param bufnr integer
    ---@param lnum integer @0-based, exclusive
    ---@param lines string[]
    function M.prepends(bufnr, lnum, lines)
      local start_lnum, stop_lnum = resolve_range(lnum)
      M.sets(bufnr, start_lnum, stop_lnum, lines)
    end
  end
end

return M
