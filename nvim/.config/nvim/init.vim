lua <<EOF
_G.profiles = require'profiles'.from_env()
if profiles.has('plug') then
    vim.api.nvim_cmd({cmd = "source", args = {string.format("%s/%s", vim.fn.stdpath('config'), "plugin.vim")}}, {})
elseif profiles.has('viz') then
    require'viz'.setup()
end
require("impatient").enable_profile()
EOF

let mapleader=" "

" self #{{{

syntax off
filetype indent off
filetype plugin on

set keywordprg="help"

" vim backup && history
set nobackup
"set backupdir  = $HOME/.vim/files/backup
"set backupext  = -vimbackup
"set backupskip =
set nowritebackup
set noswapfile
"set updatecount=100
"set directory = $HOME/.vim/files/swap/
set undofile
set undodir=$HOME/.cache/nvim/undo
set undolevels=200
set undoreload=100
set history=100
"set clipboard = unnamed " use clipboard

" vim search
set magic
set ignorecase
set smartcase
set hlsearch
set incsearch
"set wrapscan

" vim session && viminfo
" Return to last edit position when opening files
autocmd BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
set shada='100,/0,<0,s10
set sessionoptions+=blank,buffers,curdir,folds,help,options,winsize,resize
set sessionoptions+=unix,slash

" vim mouse && cursor
behave xterm
set mouse=a
set scrolloff=0
"set cursorline

" vim encoding
set encoding=utf8
let &termencoding=&encoding
set fileencoding=utf-8
set fileencodings=utf-8,ucs-bom,gbk,cp936,big5,latin-1
set ff=unix
set ffs=unix

" vim fold
set nofoldenable
set foldcolumn=0

" vim status line
set cmdheight=1
set laststatus=3

" vim complete
set completeopt=menuone,noinsert
set wildmode=full:lastused
set wildmenu
set more
set suffixes=.un~,.bak,~,.swp,.log,.data
" for vim
set wildignore+=*~,*.bak,*.un~,tags
" for git
"set wildignore+=*/.git/* " disable for fugitive
set wildignore+=*.data
set wildignore+=*.jpg,*.gif,*.png,*.psd
" for python
set wildignore+=*/__pycache__/*,*/venv*/*
" for javascript
set wildignore+=*/node_modules/*
" for zig
set wildignore+=*/zig-cache/*,*/zig-out/*

" vim spell check
"set spell spelllang=en_us

" vim UI
set colorcolumn=0
colorscheme doodlebob

" vim tag
"set notagrelative
set tagstack

" number
set number
set relativenumber
set numberwidth=2

" vim MISC
set modeline
set modelines=5
set noshowmode
set shortmess+=aoOsTIcF
"set autochdir
"set ruler
"set rulerformat=%15(%c%V\ %p%%%)
"set backspace=eol,start,indent " backspack is a bad habit
set sidescroll=20
" some charactor doesn't work in multi-line: <>,[], b,s, h,l, ~
"set whichwrap+=b,s
set noautoread
set hidden
"set lazyredraw
set showmatch
set visualbell
"set maxmem=100000 " k
set pastetoggle=<F4>
set splitbelow
set splitright
" with this, it trends to open too many window which is anonying
"set switchbuf=vsplit
set timeout
set ttimeout
set timeoutlen=1000
set ttimeoutlen=1000
"set virtualedit=block,onemore
set inccommand=

" since &swapfile was disabled, updatetime mainly set for CursorHold
set updatetime=2000

set title
set titlelen=10
set titlestring=vi:%{expand(\"%:t:r\")}
" #}}}

" tab & space & indent & linebreak #{{{

" vim tab & space
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set shiftround

" vim line display
set nowrap
set linebreak
"set breakindent
"set breakindentopt=min:40
set textwidth=78
set linespace=5
set formatoptions=tcqn2vlB1j
" CAUTION: artifacts spotted when having the option
"set display=lastline
set nolist

"#}}}

" map #{{{

" disable default
nnoremap <space> <nop>
nnoremap s       <nop>

" bash like
cnoremap <c-a> <home>
cnoremap <c-e> <end>
cnoremap <c-p> <up>
cnoremap <c-n> <down>

" switch windows
nnoremap <c-l> <c-w>l
nnoremap <c-h> <c-w>h
nnoremap <c-j> <c-w>j
nnoremap <c-k> <c-w>k

" tidy white-character
" 尾部多余空白符
command! Ts %s/\s\+$//e
" 多余空行
command! Tl %s/^\s*\n\s*$//e
" windows下的
command! Tm %s/\r//e
" 变tab为4个空格
command! Tt %s/\t/    /ge

" change default map
nnoremap 0 ^
nnoremap ^ 0
nnoremap Y y$

" pairs
nnoremap [q <cmd>cprev<cr>
nnoremap ]q <cmd>cnext<cr>
nnoremap [c <cmd>lprev<cr>
nnoremap ]c <cmd>lnext<cr>
nnoremap [b <cmd>bprev<cr>
nnoremap ]b <cmd>bnext<cr>
nnoremap [a <cmd>next<cr>
nnoremap ]a <cmd>prev<cr>

" <c-g>u for new undo step
inoremap <c-l> <c-g>u<del>
inoremap <c-a> <c-g>u<home>
inoremap <c-e> <c-g>u<end>

" changelist
nnoremap <c-;> g;
nnoremap <c-,> g,

" misc
"" for git-diff
command! Hd   /\v[<>=|]{7}
command! W    w !sudo tee % > /dev/null
command! Todo lvimgrep 'todo\|fixme' % | lopen

nnoremap \\ <cmd>call setreg('/', '')<cr>
nnoremap <leader>a <cmd>e #<cr>
nnoremap <leader>v <c-v>

" #}}}

"#{{{ builtin-plugins: netrw, tutor, tar, zip, gzip, doxygen, spellfile, vimball, cfilter

let g:loaded_netrw             = 1
let g:loaded_netrwPlugin       = 1

let g:loaded_tarPlugin         = 1
let g:loaded_tar               = 1
let g:loaded_zipPlugin         = 1
let g:loaded_zip               = 1
let loaded_gzip                = 1

let g:loaded_tutor_mode_plugin = 1
let g:load_doxygen_syntax      = 1
let loaded_spellfile_plugin    = 1
let g:loaded_vimballPlugin     = 1
let g:loaded_vimball           = 1

let loaded_matchit             = 1

"packadd cfilter
"#}}}

" plugin ultisnips #{{{
let g:UltiSnipsExpandTrigger='<tab>'
let g:UltiSnipsJumpForwardTrigger='<tab>'
let g:UltiSnipsJumpBackwardTrigger='<s-tab>'
let g:UltiSnipsEditSplit='vertical'
let g:snips_author='haoliang'
"#}}}

" plugin easy-align #{{{
let g:easy_align_ignore_groups = ['Comment', 'String']
vmap <Enter> <Plug>(EasyAlign)
"#}}}

" plugin Man #{{{
let g:ft_man_folding_enable = 1
"#}}}

" plugin commentary#{{{
vmap gc <Plug>Commentary
nmap gc <Plug>CommentaryLine
"#}}}

" plugin hop #{{{
let g:loaded_hop = 1
"#}}}

" plugin surround #{{{
let g:surround_no_insert_mappings = 1
"#}}}

" neovim #{{{
" https://github.com/neovim/neovim/issues/2093
"set ttimeoutlen=-1 " or 0
set nottimeout " 0

" 不是 <c-[>, 我还需要在terminal中使用vi-mode
tnoremap <c-]> <C-\><C-n>
"#}}}

lua <<EOF
require'bootstrap'()
EOF

" vim:fen:fdm=marker:fmr=#{{{,#}}}
