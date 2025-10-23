local M = {}

-- solution 1: vim.api.nvim_input([[<c-u>:h <c-r><c-w><cr>]])
-- solution 2: vim.fn.expand('<cword>')

local augroups = require("infra.augroups")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local feedkeys = require("infra.feedkeys")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")
local unsafe = require("infra.unsafe")
local vsel = require("infra.vsel")

local help
do
  local function has_helpwin()
    local tabid = ni.get_current_tabpage()
    local winids = ni.tabpage_list_wins(tabid)
    --the help win trends to be at the bottom
    for i = #winids, 1, -1 do
      local bufnr = ni.win_get_buf(winids[i])
      if prefer.bo(bufnr, "buftype") == "help" then return true end
    end
    return false
  end

  local function open_in_tab(subject) ex.eval("tab help %s", subject) end

  local function set_helpwin_opts(winid)
    local wo = prefer.win(winid)
    wo.list = false
    wo.wrap = false
    wo.number = false
    wo.relativenumber = false
  end

  local openmode_to_wincmd = { left = "H", right = "L", above = "K", below = "J" }

  ---@param subject string
  ---@param open_mode infra.bufopen.Mode
  function help(open_mode, subject)
    if has_helpwin() then
      if open_mode == "tab" then
        return open_in_tab(subject)
      else
        return ex("help", subject)
      end
    end

    local bufnr = Ephemeral({ namepat = "helphelp://{bufnr}", modifiable = false })
    unsafe.prepare_help_buffer(bufnr)

    local winid = rifts.open.win(bufnr, false, { relative = "editor", row = 0, col = 0, width = 1, height = 1, hide = true })

    local aug = augroups.BufAugroup(bufnr, "helphelp", false)
    aug:once("BufWipeout", {
      callback = function()
        vim.schedule(function() --to avoid E1159: cannot split a window when closing the buffer
          assert(ni.win_is_valid(winid))
          if open_mode == "inplace" then
            local help_bufnr = ni.win_get_buf(winid)
            ex("wincmd", "p")
            set_helpwin_opts(ni.get_current_win())
            ni.win_set_buf(0, help_bufnr)
            ni.win_close(winid, false)
          elseif open_mode == "tab" then
            open_in_tab(subject)
            ni.win_close(winid, false)
          else
            ex.cmd("wincmd", assert(openmode_to_wincmd[open_mode]))
            set_helpwin_opts(ni.get_current_win())
            feedkeys("zt" .. "0" .. "g$", "n")
          end
        end)
        aug:unlink()
      end,
    })

    ex("help", subject)
  end
end

function M.nvim(keyword)
  if keyword == nil then keyword = vsel.oneline_text() end
  if keyword == nil then return end
  help("right", keyword)
end

function M.luaref(keyword)
  if keyword == nil then keyword = vsel.oneline_text() end
  if keyword == nil then return end
  help("right", string.format("luaref-%s", keyword))
end

return setmetatable(M, { __call = function(_, open_mode, subject) return help(open_mode, subject) end })
