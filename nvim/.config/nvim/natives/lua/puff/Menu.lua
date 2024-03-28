-- a drop-in replacement of vim.ui.select, just like tmux's display-menu
--
--design
--* keys are subset of [a-z]
--  * order is predicatable
--* each menu have its own buffer, multiple menus can appear at the same time
--* compact window layout, less eyes movement
--  * respects cursor position
--  * respects #choices and max(#each-choice)
--* dont reset window options and buffer lines initiatively

local Ephemeral = require("infra.Ephemeral")
local jelly = require("infra.jellyfish")("puff.Menu")
local bufmap = require("infra.keymap.buffer")
local rifts = require("infra.rifts")

local api = vim.api

---@class puff.Menu
---@field private key_pool puff.KeyPool
local Menu = {}
do
  Menu.__index = Menu

  ---@param entries string[]
  ---@param formatter fun(entry: string):string
  ---@param prompt? string
  ---@param on_decide fun(entry: string?, index: number?)
  function Menu:display(entries, formatter, prompt, on_decide)
    local lines = {}
    do
      local key_iter = self.key_pool:iter()
      for _, ent in ipairs(entries) do
        local key = assert(key_iter(), "no more lhs is available")
        local line = string.format(" %s. %s", key, formatter(ent))
        table.insert(lines, line)
      end
    end

    local win_height, win_width
    do
      local line_max = 0
      for _, line in ipairs(lines) do
        if #line > line_max then line_max = #line end
      end
      win_height = #lines
      win_width = line_max + 1
    end

    local canvas = { entries = entries, on_decide = on_decide, choice = nil, bufnr = nil, winid = nil }

    do -- setup buf
      local function namefn(bufnr) return string.format("menu://%s/%d", prompt or "", bufnr) end
      canvas.bufnr = Ephemeral({ namefn = namefn, handyclose = true }, lines)

      local bm = bufmap.wraps(canvas.bufnr)
      for key in self.key_pool:iter() do
        bm.n(key, function()
          local n = assert(self.key_pool:index(key), "unreachable: invalid key")
          -- not a present entry, do nothing
          if n > api.nvim_buf_line_count(canvas.bufnr) then return jelly.info("no such option: %s", key) end
          canvas.choice = n
          api.nvim_win_close(canvas.winid, false)
        end)
      end

      api.nvim_create_autocmd("bufwipeout", {
        buffer = canvas.bufnr,
        once = true,
        callback = function()
          local choice = canvas.choice
          canvas.on_decide(canvas.entries[choice], choice)
        end,
      })
    end

    do -- display
      local winopts = { relative = "cursor", row = 1, col = 0, width = win_width, height = win_height }
      local winid = rifts.open.win(canvas.bufnr, true, winopts)
      canvas.winid = winid
    end

    -- there is no easy way to hide the cursor, let it be there
  end
end

---@param key_pool puff.KeyPool
---@return puff.Menu
return function(key_pool) return setmetatable({ key_pool = key_pool }, Menu) end
