local augroups = require("infra.augroups")
local cmds = require("infra.cmds")
local ex = require("infra.ex")
local feedkeys = require("infra.feedkeys")
local m = require("infra.keymap.global")
local ni = require("infra.ni")
local prefer = require("infra.prefer")

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

do
  ex("colorscheme", vim.go.background == "light" and "doodlebob" or "boneyard")
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
  })

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
  def.termguicolors = false
  def.wildoptions = "fuzzy,pum"
end

do -- map
  --disable default
  m.n("<space>", "<nop>")
  m.n("s", "<nop>") -- for gallop
  m.n("go", "<nop>") -- for gallop

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

  do --useful insert keymaps from emacs
    --* <c-g>u for new undo step
    --* during pum/comp, behave as `<c-e>`
    local function rhs(default)
      return function() feedkeys(vim.fn.pumvisible() == 0 and default or "<c-e>", "n") end
    end
    m.i("<c-l>", rhs("<c-g>u<del>"))
    m.i("<c-a>", rhs("<c-g>u<home>"))
    m.i("<c-e>", rhs("<c-g>u<end>"))
    m.i("<c-u>", rhs("<c-g>u<c-u>"))
  end

  --changelist
  m.n("<c-;>", "g;")
  m.n("<c-,>", "g,")

  --tabpage
  m.n("<c-t>c", function()
    local tabnr = vim.v.count
    if tabnr == 0 then return ex("tabclose") end
    ex.eval(string.format("%dtabclose", tabnr))
  end)
  m.n("<c-t>o", "<cmd>tabonly<cr>")

  --more handy for frequent operations
  m.n("<space>v", "<c-v>")
  m.n("<space>w", "<cmd>write<cr>")

  ni.set_keymap("n", "<space><space>", "<cr>", { noremap = false })
  ni.set_keymap("n", "<2-leftmouse>", "<cr>", { noremap = false })

  m.n("g/", [[<cmd>nohlsearch<cr>]])

  m.n("=", ":lua = ")

  m.t("<c-]>", [[<C-\><C-n>]])
  m.x("gs", "<c-g>") --<c-g>难按

  m.n([[']], [[`]])
  m.n([[`]], [[']])
end

do -- cmd
  local c = cmds.create

  c("Ts", [[%s/\s\+$//e]])
  c("Tl", [[:g/^\s*\n\s*$/d]]) --which is better than [[%s/^\s*\n\s*$//e]], IMO
  c("Tm", [[%s/\r//e]])

  c("Hd", [[/\v^[<>=|]{7}]]) -- git diff
end

do -- autocmd
  local aug = augroups.Augroup("boot://vim")

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
    desc = "try to focus previous win",
    nested = true,
    callback = function(args)
      local closing_winid = assert(tonumber(args.match))

      --floatwin may have a anchor window
      --* relative={win,cursor} falls in this branch
      --* relative=win will go through as landwin
      local wincfg = ni.win_get_config(closing_winid)
      if wincfg.relative == "win" then
        local anchor = assert(wincfg.win)
        if ni.win_is_valid(anchor) then
          ni.set_current_win(anchor)
        else
          --pass; it could happen for a plugin employs multiple floatwins at the same time
        end
      end

      --do nothing when closing an unfocused window
      if ni.get_current_win() ~= closing_winid then return end
      ex("wincmd", "p")
    end,
  })

  aug:repeats("TextYankPost", {
    desc = "flash the text being copied",
    callback = function() vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150, on_visual = false }) end,
  })
end

do --lua interpreter
  math.randomseed(os.time())
end

do --cmdline shortcuts
  _G.ts = vim.treesitter
  _G.uv = vim.uv
  _G.lsp = vim.lsp
  _G.dig = vim.diagnostic
  _G.vi = vim.fn
  _G.ni = ni
end
