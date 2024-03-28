local M = {}

local Augroup = require("infra.Augroup")
local bufdispname = require("infra.bufdispname")
local ex = require("infra.ex")

local api = vim.api

---@type table<number, string>
local given_names = {}

do ---setup
  local aug = Augroup("tabline://")
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
  if tabpage == nil or tabpage == 0 then tabpage = api.nvim_get_current_tabpage() end

  given_names[tabpage] = new_name
  ex("redrawtabline")
end

do
  ---@param tabpage number
  ---@return string
  local function resolve_tab_title(tabpage)
    local givenname = given_names[tabpage]
    if givenname ~= nil then return givenname end

    local winid = api.nvim_tabpage_get_win(tabpage)
    local bufnr = api.nvim_win_get_buf(winid)
    local bufname = api.nvim_buf_get_name(bufnr)

    if bufname == "" then
      return bufdispname.unnamed.short_filetype(bufnr, bufname) or bufdispname.unnamed.number(bufnr, bufname)
    else
      return bufdispname.named.short_protocol(bufnr, bufname) or bufdispname.named.relative_stem(bufnr, bufname)
    end
  end

  ---@return string
  function M.render()
    --%#TabLine#%1T init %T%#TabLineSel#%2T tabline %T%#TabLineFill#%=%#TabLine#%999XX
    --for the close mark: :h statusline X

    local parts = {}
    do
      local tabs = api.nvim_list_tabpages()
      -- only one tab, no need to set
      if #tabs == 1 then return "" end
      local cur_tabpage = api.nvim_get_current_tabpage()
      for i = 1, #tabs do
        local tabpage = tabs[i]
        local title = resolve_tab_title(tabpage)
        local focus = tabpage == cur_tabpage and "%#TabLineSel#" or "%#TabLine#"
        table.insert(parts, string.format([[%s%%%dT%s]], focus, i, title))
      end
    end

    return table.concat(parts, " ")
  end
end

return M
