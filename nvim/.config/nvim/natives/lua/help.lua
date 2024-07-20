local M = {}

-- solution 1: vim.api.nvim_input([[<c-u>:h <c-r><c-w><cr>]])
-- solution 2: vim.fn.expand('<cword>')

local ex = require("infra.ex")
local vsel = require("infra.vsel")

function M.nvim(keyword)
  if keyword == nil then keyword = vsel.oneline_text() end
  if keyword == nil then return end
  ex("help", keyword)
end

function M.luaref(keyword)
  if keyword == nil then keyword = vsel.oneline_text() end
  if keyword == nil then return end
  ex("help", string.format("luaref-%s", keyword))
end

function M.auto_right()
  if true then return end

  --it runs on every ex command, which can hurt performance
  local aug
  --inspired by github.com/ii14/autosplit.nvim
  aug:repeats("CmdlineLeave", {
    desc = "split right help",
    callback = function()
      ---@type {abort: boolean, cmdlevel: 1|integer, cmdtype: ":"|string}
      local event = vim.v.event
      if not (event.cmdtype == ":" and event.cmdlevel == 1) then return end

      vim.schedule(function()
        local bin = strlib.iter_splits(vim.fn.getreg(":"), " ")()
        if not (bin == "h" or bin == "help") then return end

        local help_winid = ni.get_current_win()
        local bufnr = ni.win_get_buf(help_winid)
        --edge case: no such help; cancelled
        if prefer.bo(bufnr, "buftype") ~= "help" then return end

        local prev_winnr = vim.fn.winnr("#")
        --edge case: <c-w>t
        if prev_winnr == 0 then return end

        if ni.win_get_width(help_winid) >= 2 * 78 then
          vim.fn.win_splitmove(help_winid, prev_winnr, { vertical = true, rightbelow = true })
        else
          local shorter_height = vim.fn.winheight(prev_winnr)
          ni.win_set_height(help_winid, shorter_height)
        end
      end)
    end,
  })
end

return M
