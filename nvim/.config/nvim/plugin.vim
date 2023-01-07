call plug#begin(stdpath('data') . '/plugged')

Plug 'lewis6991/impatient.nvim'

if v:lua.profiles.has('base')
    Plug '~/.config/nvim/machinecity'
    Plug '~/.config/nvim/zion/kite'
    Plug 'tpope/vim-repeat'
    Plug 'junegunn/vim-easy-align'
    Plug 'michaeljsmith/vim-indent-object'
    Plug 'tpope/vim-surround'
    Plug 'haolian9/reveal.nvim', {'do': 'make link-vifm-plugin'}
    Plug 'haolian9/hop.nvim', {'branch': 'hal'}
endif

if v:lua.profiles.has('joy')
    Plug 'haolian9/guwen.nvim'
endif

if v:lua.profiles.has('lsp')
    Plug 'neovim/nvim-lspconfig'
    " optionally required by: null-ls
    Plug 'nvim-lua/plenary.nvim'
    Plug 'haolian9/null-ls.nvim', {'branch': 'hal'}
endif

if v:lua.profiles.has('treesitter')
    Plug 'haolian9/nvim-treesitter', {'do': ':TSUpdate', 'branch': 'hal'}
    Plug 'nvim-treesitter/playground'
endif

if v:lua.profiles.has('code')
    Plug 'SirVer/ultisnips'
    Plug 'tpope/vim-commentary'
endif

if v:lua.profiles.has('git')
    Plug 'tpope/vim-fugitive'
    Plug 'junegunn/gv.vim'
endif

if v:lua.profiles.has('lua')
    Plug 'haolian9/emmylua-stubs'
endif

if v:lua.profiles.has('wiki')
    Plug '~/.config/nvim/zion/wiki'
endif

call plug#end()
