local Augroup = require("infra.Augroup")
local cmds = require("infra.cmds")
local ex = require("infra.ex")
local fn = require("infra.fn")
local m = require("infra.keymap.global")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local api = vim.api

local function resolve_clipboard_provider()
  -- x11
  if vim.env.DISPLAY ~= nil then
    return {
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
  end

  -- tmux
  if vim.env.TMUX ~= nil then
    return {
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
  end

  -- no luck left
  return false
end

local function short_apis()
  local apis = {}
  for k, v in pairs(vim.api) do
    if strlib.startswith(k, "nvim_") then apis[string.sub(k, #"nvim_" + 1)] = v end
  end
  return apis
end

do --avoid bad defaults
  local global = vim.g
  local def = prefer.def

  ex("syntax", "off")
  ex("filetype", "plugin", "indent", "off")

  def.loadplugins = false -- so that no need to turn off {netrw,tar,zip,tutor,vimball,...} explictly
  global.editorconfig = false
end

do --saner background
  local bgmode = os.getenv("BGMODE") or "light"
  prefer.def.background = bgmode
  ex("colorscheme", bgmode == "light" and "doodlebob" or "boneyard")
end

do -- vim options
  local global = vim.g
  local def = prefer.def

  global.mapleader = " "

  -- backup && history
  def.backup = false
  def.writebackup = false
  def.swapfile = false
  def.undofile = false
  def.undolevels = 100
  def.undoreload = 0
  def.history = 100

  -- search
  def.ignorecase = true
  def.smartcase = true

  -- encoding
  def.fileencoding = "utf-8"
  def.fileencodings = "utf-8"
  def.fileformat = "unix"
  def.fileformats = "unix"

  -- complete
  def.completeopt = "menuone,noinsert"
  def.wildmode = "full:lastused"
  def.suffixes = ".un~,.bak,~,.swp,.log,.data"
  def.wildignore = table.concat({
    "*/.git/*",
    "*/__pycache__/*,*/venv*/*",
    "*/node_modules/*",
    "*/zig-cache/*,*/zig-out/*",
  }, ",")

  -- ui
  def.number = false
  def.relativenumber = false
  def.numberwidth = 1
  def.signcolumn = "no"
  def.cmdheight = 1
  def.laststatus = 3
  def.foldenable = false

  -- tab & space
  def.tabstop = 4
  def.softtabstop = 4
  def.shiftwidth = 4
  def.expandtab = true
  def.shiftround = true

  -- line display
  def.wrap = false
  def.linebreak = true
  def.textwidth = 128
  def.formatoptions = table.concat({
    "t", --auto-wrap text using 'textwidth'
    "c", --auto-wrap comments using 'textwidth'
    "q", --allow formatting of comments with "gq".
    "n", --recognize numbered lists
    "2", --首行缩进

    "v", --only break a line at a blank that you have entered during the current insert command
    "l", --long lines are not broken in insert mode
    "1", --don't break a line after a one-letter word

    "j", --remove a comment leader when joining lines
    "B", --when joining lines, don't insert a space between two multibyte characters

    --unwanted behaviors
    -- 'r', --insert the current comment leader after hitting <Enter> in Insert mode.
    -- "o", --insert the current comment leader after hitting 'o' or 'O' in Normal mode.
  }, "")

  -- misc
  def.shada = [[:100,@100,@100,'0,f0,/0,<0,s10,h]]
  def.keywordprg = ":help"
  def.modeline = true
  def.modelines = 2 -- for both vim and windmill
  def.showmode = false
  def.shortmess = "filnxtToOF" .. "aoOsTIcF"
  def.autochdir = false
  def.autoread = false
  def.sidescroll = 20
  def.showmatch = true
  def.visualbell = true
  def.splitbelow = true
  def.splitright = true
  def.inccommand = ""
  def.title = true
  def.titlelen = 32
  def.titlestring = [[vi@%{fnamemodify(getcwd(), ':t:r')}]]
  global.clipboard = resolve_clipboard_provider()
  def.virtualedit = "block"
  def.scrollback = 150 -- 50 * 3 screens is enough for me
  def.jumpoptions = "stack"
  def.fsync = false
end

-- stylua: ignore
do -- map
  --disable default
  m.n("<space>", "<nop>")
  m.n("s",       "<nop>")  -- for gallop
  m.n("go",      "<nop>") -- for gallop

  --bash-ish
  m.c("<c-a>", "<home>")
  m.c("<c-e>", "<end>")
  m.c("<c-p>", "<up>")
  m.c("<c-n>", "<down>")

  --switch window
  m.n("<c-l>", "<c-w>l")
  m.n("<c-h>", "<c-w>h")
  m.n("<c-j>", "<c-w>j")
  m.n("<c-k>", "<c-w>k")

  --better default
  m.n("0", "^")
  m.n("^", "0")
  m.n("Y", "y$")

  --pairs
  m.n("[q", "<cmd>cprev<cr>")
  m.n("]q", "<cmd>cnext<cr>")
  m.n("[c", "<cmd>lprev<cr>")
  m.n("]c", "<cmd>lnext<cr>")
  m.n("[b", "<cmd>bprev<cr>")
  m.n("]b", "<cmd>bnext<cr>")
  m.n("[a", "<cmd>prev<cr>")
  m.n("]a", "<cmd>next<cr>")

  --<c-g>u for new undo step
  m.i("<c-l>", "<c-g>u<del>")
  m.i("<c-a>", "<c-g>u<home>")
  m.i("<c-e>", "<c-g>u<end>")

  --changelist
  m.n("<c-;>", "g;")
  m.n("<c-,>", "g,")

  m.n('g/', [[<cmd>nohlsearch<cr>]])

  m.n("<leader>a", "<c-^>")
  m.n("<leader>v", "<c-v>")
  api.nvim_set_keymap("n", "<space><space>", "<cr>", { noremap = false })

  -- at this moment
  -- this is stupid but necessary to survive from when `<tab>` is being maped
  -- but tmux does not distinguish tab and c-i
  m.n("<c-i>", "<c-i>")

  m.t("<c-]>", [[<C-\><C-n>]])
  m.x("gs",    "<c-g>") --<c-g>难按
end

do -- cmd
  local c = cmds.create

  c("Ts", [[%s/\s\+$//e]])
  c("Tl", [[%s/^\s*\n\s*$//e]])
  c("Tm", [[%s/\r//e]])

  c("Hd", [[/\v^[<>=|]{7}]]) -- git diff
end

do -- autocmd
  local aug = Augroup("boot://vim")

  aug:repeats("StdinReadPre", {
    desc = "make stdin buffer disposable",
    callback = function(event)
      local bo = prefer.buf(event.buf)
      -- same as scratch-buffer
      bo.buftype = "nofile"
      bo.bufhidden = "hide"
      bo.swapfile = false
    end,
  })

  aug:repeats("WinClosed", {
    desc = "reasonable focus change",
    nested = true,
    callback = function(args)
      -- do nothing when closing an unfocused window
      if api.nvim_get_current_win() ~= tonumber(args.match) then return end
      ex("wincmd", "p")
    end,
  })

  aug:repeats("TextYankPost", {
    desc = "flash the text being copied",
    callback = function() vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150, on_visual = false }) end,
  })

  --inspired by github.com/ii14/autosplit.nvim
  aug:repeats("CmdlineLeave", {
    desc = "split right help",
    callback = function()
      ---@type {abort: boolean, cmdlevel: 1|integer, cmdtype: ":"|string}
      local event = vim.v.event
      if not (event.cmdtype == ":" and event.cmdlevel == 1) then return end

      vim.schedule(function()
        local bin = fn.split_iter(vim.fn.getreg(":"), " ")()
        if not (bin == "h" or bin == "help") then return end

        local help_winid = api.nvim_get_current_win()
        local bufnr = api.nvim_win_get_buf(help_winid)
        --edge case: no such help; cancelled
        if prefer.bo(bufnr, "buftype") ~= "help" then return end

        local prev_winnr = vim.fn.winnr("#")
        --edge case: <c-w>t
        if prev_winnr == 0 then return end

        if api.nvim_win_get_width(help_winid) >= 2 * 78 then
          vim.fn.win_splitmove(help_winid, prev_winnr, { vertical = true, rightbelow = true })
        else
          local shorter_height = vim.fn.winheight(prev_winnr)
          api.nvim_win_set_height(help_winid, shorter_height)
        end
      end)
    end,
  })
end

do --lua interpreter
  math.randomseed(os.time())
end

do --cmdline shortcuts
  _G.api = short_apis()
  _G.ts = vim.treesitter
  _G.uv = vim.loop
  _G.lsp = vim.lsp
  _G.dig = vim.diagnostic
end
