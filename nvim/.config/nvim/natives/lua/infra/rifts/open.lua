local M = {}

local ctx = require("infra.ctx")
local dictlib = require("infra.dictlib")
local ex = require("infra.ex")
local jelly = require("infra.jellyfish")("infra.rifts.open", "debug")
local mi = require("infra.mi")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local facts = require("infra.rifts.facts")
local geo = require("infra.rifts.geo")

---@class infra.rifts.BasicOpenOpts
---@field relative?   'editor'|'win'|'cursor'|'mouse'
---@field win?       integer @for relative=win
---@field anchor?    'NW'|'NE'|'SW'|'SE' @nil=NW
---@field width?     integer
---@field height?    integer
---@field row?       integer
---@field col?       integer
---@field focusable? boolean @nil=true
---@field zindex?    integer @nil=50; ins pum=100, cmdline pum=250
---@field style?     'minimal' @nil=minimal
---@field border?    'none'|'single'|'double'|'rounded'|'solid'|'shadow'|string[][]
---@field title?     string|[string,string][] @(text, higroup)
---@field title_pos? 'left'|'center'|'right'
---@field noautocmd? boolean @nil=false

local resolve_border
do
  local border_widths = { none = 0, single = 1, double = 2, rounded = 1, solid = 1, shadow = 2 }
  ---@param basic infra.rifts.BasicOpenOpts
  ---@return integer
  function resolve_border(basic)
    assert(not (basic.border and type(basic.border) == "table"), "not support opts.border table")
    return border_widths[basic.border] or 0
  end
end

---a nvim_open_win wrapper for floatwins
---@param bufnr integer
---@param enter boolean
---@param opts vim.api.keyset.win_config
---@return integer
function M.win(bufnr, enter, opts)
  assert(opts.split == nil, "rifts.open is designed for floatwins")

  local winid = mi.open_win(bufnr, enter, opts)

  do --curwin sensitive
    local function setup()
      --to clear alternate-file, thanks to ii14
      vim.fn.setreg("#", bufnr)
      --no sharing jumplist
      ex("clearjumps")
      --make eob:~ invisible. :h EndOfBuffer
      prefer.wo(winid, "fillchars", "eob: ")
      --todo: 'mark is meaningless for a new floatwin
    end

    if enter then
      setup()
    else
      ctx.win(winid, setup)
    end
  end

  return winid
end

do
  ---@class infra.rifts.ExtraOpenOpts
  ---@field width       number @<1, &columns%; >=1, columns
  ---@field height      number @<1, &lines%; >=1, lines
  ---@field horizontal? 'mid'|'left'|'right' @nil=mid
  ---@field vertical?   'mid'|'top'|'bot' @nil=mid
  ---@field ns          nil|integer|false @nil=rifts.ns, false=no set

  ---@param basic infra.rifts.BasicOpenOpts
  ---@param extra? infra.rifts.ExtraOpenOpts
  ---@return table
  local function resolve_winopts(basic, extra)
    if extra == nil then return basic end

    return dictlib.merged(basic, geo.editor(extra.width, extra.height, extra.horizontal, extra.vertical, resolve_border(basic)))
  end

  ---opinionated ni.open_win
  ---* relative     to editor
  ---* width/height float|integer
  ---* horizontal   for col
  ---* vertical     for row
  ---
  ---@param bufnr integer
  ---@param enter boolean
  ---@param basic_opts? infra.rifts.BasicOpenOpts
  ---@param extra_opts? infra.rifts.ExtraOpenOpts
  ---@return integer
  function M.fragment(bufnr, enter, basic_opts, extra_opts)
    basic_opts = basic_opts or {}
    if basic_opts.relative and basic_opts.relative ~= "editor" then
      return jelly.fatal("InvalidValue", ".relative in rifts.open.* should always be editor")
    else
      basic_opts.relative = "editor"
    end

    if extra_opts == nil then
      local winid = M.win(bufnr, enter, basic_opts)
      ni.win_set_hl_ns(winid, facts.ns)
      return winid
    end

    local winid = M.win(bufnr, enter, resolve_winopts(basic_opts, extra_opts))
    if extra_opts.ns == nil then
      ni.win_set_hl_ns(winid, facts.ns)
    elseif extra_opts.ns == false then
      --pass, no setting ns
    else
      ni.win_set_hl_ns(winid, extra_opts.ns)
    end

    return winid
  end
end

do
  ---@param basic infra.rifts.BasicOpenOpts
  ---@return table
  local function resolve_winopts(basic)
    assert(not (basic.border and type(basic.border) == "table"), "not support opts.border table")
    return dictlib.merged(basic, geo.fullscreen(resolve_border(basic)))
  end

  ---no covering cmdline and laststatus=3 (opt-in)
  ---@param bufnr integer
  ---@param enter boolean
  ---@param basic_opts? infra.rifts.BasicOpenOpts
  ---@param extra_opts? {ns: nil|integer|false, laststatus3?: boolean}
  ---@return integer winid
  function M.fullscreen(bufnr, enter, basic_opts, extra_opts)
    basic_opts = basic_opts or {}
    if basic_opts.relative and basic_opts.relative ~= "editor" then
      return jelly.fatal("InvalidValue", ".relative in rifts.open.* should always be editor")
    else
      basic_opts.relative = "editor"
    end

    extra_opts = extra_opts or {}

    ---concern: may conflict with vim.ui.ext.cmdline
    local winopts = resolve_winopts(basic_opts)
    if extra_opts.laststatus3 and vim.go.laststatus == 3 then winopts.height = winopts.height - 1 end

    local winid = M.win(bufnr, enter, winopts)
    if extra_opts.ns ~= false then ni.win_set_hl_ns(winid, extra_opts.ns or facts.ns) end
    return winid
  end
end

return M
