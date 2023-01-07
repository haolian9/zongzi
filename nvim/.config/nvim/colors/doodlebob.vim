" design: less color, more concentrated
"
" severities:
" * trace: comment, string literal, punctuation
" * debug: if, try...catch, for, const/var, switch/match
" * info: identifier/func/variable
" * warning: async/await, defer
" * error: return, try
"
" todo: proper hi for fts
" * ft=gitcommit (:Git commit)
" * [x] ft=git (:GV)
" * ft=make
" * ft=fugitive (:0Git)

" Reset to light background, then reset everything to defaults:
set background=light
highlight clear
if exists("syntax_on")
    syntax reset
endif

let g:colors_name="doodlebob"

" vim relevant #{{{
hi Folded       ctermfg=243       ctermbg=none  cterm=none
hi FoldColumn   ctermfg=243       ctermbg=none  cterm=bold
hi SignColumn   ctermfg=black     ctermbg=none  cterm=none
hi Visual       ctermfg=black     ctermbg=222   cterm=none
hi VisualNOS    ctermfg=black     ctermbg=222   cterm=none
hi StatusLine   ctermfg=red       ctermbg=none  cterm=bold,underline
hi StatusLineNC ctermfg=black     ctermbg=none  cterm=bold,underline
hi WinsEparator ctermfg=7         ctermbg=none  cterm=none

hi IncSearch    ctermfg=black     ctermbg=222   cterm=bold
hi Search       ctermfg=black     ctermbg=222   cterm=none

hi WildMenu     ctermfg=black     ctermbg=222   cterm=none

hi PMenu        ctermfg=0         ctermbg=7     cterm=none
hi PMenuSel     ctermfg=15        ctermbg=6     cterm=bold
hi PMenuSbar    ctermfg=15        ctermbg=15    cterm=none
hi PMenuThumb   ctermfg=15        ctermbg=7     cterm=none

hi CursorColumn cterm=none
hi CursorLine   cterm=bold

hi TabLine      ctermfg=black     ctermbg=none  cterm=none
hi TabLineSel   ctermfg=red       ctermbg=none  cterm=bold
hi TabLineFill  ctermbg=none      ctermbg=none  cterm=none

hi ColorColumn  ctermbg=lightgray ctermfg=red   cterm=bold

hi LineNr       ctermfg=darkgray  ctermbg=none  cterm=none
hi CursorLineNr ctermfg=black     ctermbg=none  cterm=bold

"misc
hi Whitespace   ctermfg=white     ctermbg=black cterm=none
hi MatchParen   ctermfg=15        ctermbg=14    cterm=none
hi MsgSeparator ctermfg=9         ctermbg=15    cterm=underline
"#}}}

" diff #{{{
hi diffAdded   ctermfg=8
hi diffRemoved ctermfg=243
hi diffChanged ctermfg=5
hi diffFile    ctermfg=0 cterm=bold
hi gitDiff     ctermfg=0
"#}}}

" statusline #{{{
" see init.vim/statusline
hi StatusLineBufStatus ctermfg=8 cterm=bold
hi StatusLineFilePath  ctermfg=9
hi StatusLineAltFile   ctermfg=240
hi StatusLineCursor    ctermfg=8
hi StatusLineSpan      ctermfg=15
hi StatusLineRepeat    ctermfg=8
" #}}}

" general grammar token #{{{
" :h group-name

hi Normal     ctermfg=8
hi Comment    ctermfg=241
hi Todo       ctermfg=9 ctermbg=15 cterm=bold
"hi Underlined
"hi Ignore
"hi Error


"" any constant
hi Constant   ctermfg=235
hi String     ctermfg=240
"hi Character
"hi Number
"hi Boolean
"hi Float

"" any variable name
hi Identifier ctermfg=8
hi Function   ctermfg=8

"" any statement
hi Statement  ctermfg=240
"hi Operator
"hi Keyword
"hi Conditional
"hi Repeat
"hi Label
"hi Exception

"" generic Preprocessor
hi PreProc    ctermfg=8
"hi Include
"hi Define
"hi Macro
"hi PreCondit

"" int, long, char, etc; struct, union, enum, etc.
hi Type       ctermfg=8
"hi Structure
"hi Typedef
"hi StorageClass

"" any special symbol
hi Special    ctermfg=8
hi Delimiter  ctermfg=240
"hi SpecialChar
"hi Tag
"hi SpecialComment
"hi Debug

"#}}}

" lsp #{{{
" :h hl-TS*
"

hi @error                 ctermfg=8 cterm=underline

hi @function              ctermfg=8
hi @variable              ctermfg=8
hi @function.builtin      ctermfg=8
hi @type.builtin          ctermfg=8
hi @variable.builtin      ctermfg=8
hi @constant.builtin      ctermfg=8

hi @keyword               ctermfg=31
hi @keyword.function      ctermfg=31
hi @function.macro        ctermfg=31

hi @keyword.return        ctermfg=124

hi @keyword.operator      ctermfg=240
hi @exception             ctermfg=240
hi @type.qualifier        ctermfg=240
hi @string.escape         ctermfg=240
hi @string.special        ctermfg=240
hi @punctuation.delimiter ctermfg=240
hi @punctuation.special   ctermfg=240
hi @punctuation.bracket   ctermfg=240
hi @punctuation.bracket   ctermfg=240

" #}}}

" diagnostic #{{{
hi DiagnosticHint ctermfg=darkgray
"#}}}

" vim:fen:fdm=marker:fmr=#{{{,#}}}
