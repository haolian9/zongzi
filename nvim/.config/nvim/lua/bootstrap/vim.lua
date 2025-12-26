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
  def.completeopt = "noinsert,nosort,menuone"
  def.wildmode = "full:lastused"
  def.wildoptions = "fuzzy,pum"
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

  -- diff
  def.diffopt = table.concat({
    "internal",
    "algorithm:patience",
    "closeoff",
    "filler",
    "linematch:60",
  }, ",")

  -- misc
  def.shada = "" --[[:100,@100,@100,'0,f0,/0,<0,s10,h]]
  def.keywordprg = ":help"
  def.modeline = true
  def.modelines = 2 -- for both vim and Mill
  def.showmode = false
  def.shortmess = "filnxtToOF" .. "aoOsTIcF"
  def.autochdir = false
  def.autoread = false
  def.sidescroll = 20
  def.showmatch = false --视觉效果过于迟滞(即使有matchtime=1)，还会短暂失去光标
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
end

do -- map
  --disable default
  m.n("<space>", "<nop>")
  m.n("s", "<nop>") -- for gallop
  m.n("go", "<nop>") -- for gallop

  --cmd mode emacs
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
  m.n("'", "`")
  m.n("`", "'")
  m.n("Y", "y$")

  ---insert mode emacs
  --NB: <c-g>u for new undo step
  m.i("<c-l>", "<c-g>u<del>")
  m.i("<c-a>", "<home>")
  m.i("<c-e>", "<end>")
  m.i("<c-u>", "<c-g>u<c-u>")
  m.i("<c-h>", "<c-g>u<c-h>")
  m.i("<c-w>", "<c-g>u<c-w>")

  m.i("<c-d>", function() feedkeys(vim.fn.pumvisible() == 0 and "<c-d>" or "<pagedown>", "n") end)

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

  ---intented enabling recursive map to trigger plugin set <cr>
  ni.set_keymap("n", "<space><space>", "<cr>", { noremap = false })
  ni.set_keymap("n", "<2-leftmouse>", "<cr>", { noremap = false })

  m.n("g/", [[<cmd>nohlsearch<cr>]])

  m.t("<c-]>", [[<C-\><C-n>]])
  m.x("gs", "<c-g>") --<c-g>难按
end

do -- cmd
  do --:Trim
    local spell = cmds.Spell("Trim", function(args)
      local cmd = args.cmd
      if cmd == "spaces" then
        ex.eval([[keepp %s/\s\+$//e]])
      elseif cmd == "blanklines" then
        ex.eval([[keepp g/^\s*\n\s*$/d]])
      elseif cmd == "cr" then
        ex.eval([[keepp %s/\r//e]])
      end
    end)
    local comp = cmds.ArgComp.constant({ "spaces", "blanklines", "cr" })
    spell:add_arg("cmd", "string", true, nil, comp)
    cmds.cast(spell)
  end

  cmds.create("Hd", [[/\v^[<>=|]{7}]]) -- git diff
end

do -- autocmd
  local aug = augroups.Augroup("hal://vim")

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
    callback = function() vim.hl.on_yank({ higroup = "IncSearch", timeout = 150, on_visual = false }) end,
  })
end

do --lua interpreter
  math.randomseed(os.time())
end

do --global module alias
  _G.ts = vim.treesitter
  _G.uv = vim.uv
  _G.lsp = vim.lsp
  _G.dig = vim.diagnostic
  _G.vi = vim.fn
end

do --vim builtin plugins
  local global = vim.g
  global.ft_man_folding_enable = true
end

