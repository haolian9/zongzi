local M = {}

local bufdispname = require("infra.bufdispname")

local api = vim.api

local function resolve_tab_title(bufnr)
  local bufname = api.nvim_buf_get_name(bufnr)
  local buftype = api.nvim_buf_get_option(bufnr, "buftype")

  -- regular file
  if buftype == "" then
    return bufdispname.blank(bufnr, bufname) or bufdispname.stem(bufnr, bufname)
  else
    return bufdispname.proto_abbr(bufnr, bufname) or bufdispname.filetype_abbr(bufnr, bufname) or bufname
  end
end

---@return string
function M.render()
  -- %#TabLine#%1T init %T%#TabLineSel#%2T tabline %T%#TabLineFill#%=%#TabLine#%999XX

  local parts = {}
  do
    local tabs = api.nvim_list_tabpages()
    -- only one tab, no need to set
    if #tabs == 1 then return "" end
    local cur_tab_id = api.nvim_get_current_tabpage()
    for i = 1, #tabs do
      local tab_id = tabs[i]
      local title
      do
        -- todo: get these list in one api query
        local win_id = api.nvim_tabpage_get_win(tab_id)
        local bufnr = api.nvim_win_get_buf(win_id)
        title = resolve_tab_title(bufnr)
      end
      local focus = tab_id == cur_tab_id and "%#TabLineSel#" or "%#TabLine#"
      table.insert(parts, string.format([[%s%%%dT%s]], focus, i, title))
    end
    if not "i need a button" then table.insert(parts, "%T%#TabLineFill#%=%#TabLine#%999XX") end
  end

  return table.concat(parts, " ")
end

return M
