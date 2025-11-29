---design choices
---* cache would have big performance improvement
---  * cursor position updates on every move
---
--- ref: :h statusline

local M = {}

local augroups = require("infra.augroups")
local logging = require("infra.logging")
local LRU = require("infra.LRU")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")
local unsafe = require("infra.unsafe")

local names = require("linesexpr.resolve_bufname")

local log = logging.newlogger("linesexpr.statusline", "info")

local repeat_cmd
do
  local max = 25
  local half = math.floor(max / 2)

  local function shortten(str)
    if #str <= max then return str end
    --* 插入模式的输入字符串，中间部分并不重要
    return string.format("%s..%s", string.sub(str, 1, half), string.sub(str, -half))
  end

  ---@param str string
  ---@param mark string
  ---@return string?
  local function resolve_by_mark(str, mark)
    local start = strlib.find(str, mark)
    if start == nil then return end
    local head = string.sub(str, 1, start - 1)
    local body = string.sub(str, start + #mark + 1)
    return string.format(".%s %s", head, shortten(body))
  end

  local special_cases = {
    "<80><fd>g", --d<80><fd>g77^@
    "<80><fd>h", --<cmd>..<cr>
    ":lua ", --d:lua require'nvim-treesitter.textobjects.select'.select_textobject('@function.inner', 'o')\n
    ":cal ", --d:cal <SNR>29_HandleTextObjectMapping(1, 0, 0, [line("."), line("."), col("."), col(".")])\n
  }

  ---@return string
  function repeat_cmd()
    --normal mode only
    if ni.get_mode().mode ~= "n" then return "" end

    local cmd = unsafe.get_inserted()
    if cmd == nil or cmd == "" then return "" end

    for _, mark in ipairs(special_cases) do
      local translated = resolve_by_mark(cmd, mark)
      if translated ~= nil then return translated end
    end

    return "." .. shortten(cmd)
  end
end

local get_error_number
do
  ---@type {[integer]: integer} @{bufnr: the number of diagnostics}
  local records = LRU(256)

  local aug = augroups.Augroup("statusline://")
  aug:repeats("DiagnosticChanged", {
    callback = function(args)
      local bufnr = args.buf
      local digs = args.data.diagnostics

      records[bufnr] = #digs
    end,
  })

  ---@param bufnr integer
  ---@return string
  function get_error_number(bufnr)
    assert(bufnr ~= nil and bufnr ~= 0)
    local n = records[bufnr] or 0
    if n == 0 then return "" end
    return string.format("!%d", n)
  end
end

local build_expr
do
  ---@class statusline.record
  ---@field tick number
  ---@field parts string[]

  --{bufnr: record}
  ---@as {[number]: statusline.record}
  local cache = LRU(128)

  --return (record, have_cached_before_get)
  ---@return statusline.record, boolean
  local function _get(bufnr)
    if cache[bufnr] then return cache[bufnr], true end
    cache[bufnr] = { tick = 0, parts = {} }
    return cache[bufnr], false
  end

  ---@return string
  local function resolve_fname(bufnr)
    local result
    local bufname = ni.buf_get_name(bufnr)
    if bufname == "" then
      result = names.unnamed.filetype(bufnr, bufname) or names.unnamed.number(bufnr, bufname)
    else
      result = names.named.protocol(bufnr, bufname) or names.named.relative(bufnr, bufname)
    end
    return assert(result)
  end

  ---@return string
  local function resolve_alt_fname(alt_bufnr)
    if alt_bufnr == -1 then return "" end

    local result
    local bufname = ni.buf_get_name(alt_bufnr)
    if bufname == "" then
      result = names.unnamed.short_filetype(alt_bufnr, bufname) or names.unnamed.number(alt_bufnr, bufname)
    else
      result = names.named.short_protocol(alt_bufnr, bufname) or names.named.basename(alt_bufnr, bufname)
    end
    return assert(result)
  end

  ---@param bufnr integer
  ---@return string
  local function resolve_pos(bufnr)
    if prefer.bo(bufnr, "buftype") == "terminal" then return "n/a" end

    --current lnum / total lines
    return "%c,%l/%L"
  end

  ---@param fresh boolean
  ---@return string @&statusline expr
  function build_expr(fresh)
    local bufnr = ni.get_current_buf()
    local alt_bufnr = vim.fn.bufnr("#")
    if bufnr == alt_bufnr then alt_bufnr = -1 end

    local record, have_cached_before = _get(bufnr)
    local tick = ni.buf_get_changedtick(bufnr)
    local have_changed = tick ~= record.tick

    if fresh then have_changed = true end

    local parts

    local left = "%<"
    local center = "%="
    local alt_file = resolve_alt_fname(alt_bufnr)

    if not have_cached_before or have_changed then
      parts = {}
      local function add(fmt, ...) table.insert(parts, string.format(fmt, ...)) end

      -- left part
      add([[%%#StlRepeat#%s%s]], left, repeat_cmd())
      -- center part
      add([[%%#StlSpan#%s]], center)
      add([[%%#StlFile#%s]], resolve_fname(bufnr))
      add([[%%#StlDirty#%s ]], "%M")
      add([[%%#StlAltFile#%s%s]], left, alt_file)
      add([[%%#StlSpan#%s]], center)
      -- right part
      add([[%%#StlErrors#%s ]], get_error_number(bufnr))
      add([[%%#StlCursor#%s]], resolve_pos(bufnr))
    else
      parts = record.parts
      ---@param index integer @index<0, -1 = last one
      local function set(index, val) parts[#parts - (-index - 1)] = val end

      set(-4, string.format([[%%#StlAltFile#%s%s]], left, alt_file))
      set(-2, string.format([[%%#StlErrors#%s ]], get_error_number(bufnr)))
    end

    record.tick = tick
    record.parts = parts

    return table.concat(parts)
  end
end

---@param fresh boolean @nil=false
function M.expr(fresh)
  if fresh == nil then fresh = false end
  local ok, result = xpcall(build_expr, debug.traceback, fresh)
  if ok then return result end
  log.err("%s", result)
  return "--xx-err-xx--"
end

return M
