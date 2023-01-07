local profiles = require("profiles")

local api = vim.api
local ex = require("infra.ex")

local function setup_clipboard_provider()
  -- x11
  if vim.env.DISPLAY ~= nil then
    vim.g.clipboard = {
      name = "xsel",
      copy = {
        ["+"] = { "xsel", "--nodetach", "-ib" },
        ["*"] = { "xsel", "--nodetach", "-ip" },
      },
      paste = {
        ["+"] = { "xsel", "-ob" },
        ["*"] = { "xsel", "-op" },
      },
      cache_enabled = true,
    }
    return
  end

  -- tmux
  if vim.env.TMUX ~= nil then
    vim.g.clipboard = {
      name = "tmux",
      copy = {
        ["+"] = { "tmux", "load-buffer", "-" },
        ["*"] = { "tmux", "load-buffer", "-" },
      },
      paste = {
        ["+"] = { "tmux", "save-buffer", "-" },
        ["*"] = { "tmux", "save-buffer", "-" },
      },
      cache_enabled = true,
    }
    return
  end

  -- no luck left
  vim.g.clipboard = false
end

local function setup_foreign_plugins()
  require("foreign.matrix").setup()

  if profiles.has("base") then require("foreign.hop").setup() end
  if profiles.has("joy") then require("foreign.guwen").setup() end

  if profiles.has("lsp") then
    require("foreign.lsp").setup()
    require("foreign.null-ls").setup()
  end

  if profiles.has("treesitter") then
    --
    require("foreign.treesitter").setup()
  end
end

local function setup_globals()
  _G.inspect = function(...)
    require("inspect").popup(...)
  end
end

local has_ran = false

return function()
  assert(not has_ran, "should only bootstrap once")
  has_ran = true

  setup_clipboard_provider()

  api.nvim_create_user_command("ClearSearch", function()
    vim.fn.setreg([[/]], "")
  end, { nargs = 0 })

  api.nvim_create_autocmd("StdinReadPre", {
    callback = function(event)
      local bo = vim.bo[event.buf]
      -- same as scratch-buffer
      bo.buftype = "nofile"
      bo.bufhidden = "hide"
      bo.swapfile = false
    end,
  })

  api.nvim_create_autocmd("WinClosed", {
    callback = function(args)
      -- do nothing when closing an unfocused window
      if api.nvim_get_current_win() ~= tonumber(args.match) then return end
      ex("wincmd", "p")
    end,
  })

  api.nvim_create_autocmd("TextYankPost", {
    callback = function()
      vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150, on_visual = true })
    end,
  })

  setup_globals()
  setup_foreign_plugins()
end
