local M = {}

local ropes = require("string.buffer")

local augroups = require("infra.augroups")
local ex = require("infra.ex")
local logging = require("infra.logging")
local ni = require("infra.ni")

local log = logging.newlogger("linesexpr.tabline", "info")

local names = require("linesexpr.resolve_bufname")

---@type table<number, string>
local given_names = {}

do ---init
  local aug = augroups.Augroup("tabline://")
  aug:repeats("TabClosed", {
    ---@param args {buf: number, event: string, file: string, id: number, match: string}
    callback = function(args)
      local tabpage = assert(tonumber(args.file))
      given_names[tabpage] = nil
    end,
  })
end

-- possible operations:
-- * (nil, nil)
-- * (number, nil)
-- * (nil, string)
-- * (number, string)
---@param new_name string?
---@param tabpage number?
function M.rename(new_name, tabpage)
  if tabpage == nil or tabpage == 0 then tabpage = ni.get_current_tabpage() end

  given_names[tabpage] = new_name
  ex("redrawtabline")
end

do
  ---@param tabpage number
  ---@return string
  local function resolve_tab_title(tabpage)
    local givenname = given_names[tabpage]
    if givenname ~= nil then return givenname end

    local winid = ni.tabpage_get_win(tabpage)
    local bufnr = ni.win_get_buf(winid)
    local bufname = ni.buf_get_name(bufnr)

    if bufname == "" then
      return names.unnamed.short_filetype(bufnr, bufname) or names.unnamed.number(bufnr, bufname)
    else
      return names.named.short_protocol(bufnr, bufname) or names.named.basename(bufnr, bufname)
    end
  end

  local rope = ropes.new(4096)

  ---@return string
  local function build_expr()
    --%#TabLine#%1T init %T%#TabLineSel#%2T tabline %T%#TabLineFill#%=%#TabLine#%999XX
    --for the close mark: :h statusline X

    local tabs = ni.list_tabpages()
    -- only one tab, no need to set
    if #tabs == 1 then return "" end

    local cur_tabpage = ni.get_current_tabpage()
    for i = 1, #tabs do
      local tabpage = tabs[i]
      local title = resolve_tab_title(tabpage)
      local focus = tabpage == cur_tabpage and "%#TabLineSel#" or "%#TabLine#"
      rope:putf([[ %s%%%dT%s]], focus, i, title)
    end
    rope:skip(#" ")

    return rope:get()
  end

  ---@return string
  function M.expr()
    local ok, result = xpcall(build_expr, debug.traceback)
    if ok then return result end
    log.err("%s", result)
    return "--xx-err-xx--"
  end
end

return M
