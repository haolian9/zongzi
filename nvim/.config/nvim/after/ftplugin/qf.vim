setl syn=qf
runtime syntax/qf.vim

" no local statusline
set statusline<

" quickfix window was used to show diagnositcs of linter, which would be long
setl wrap
nnoremap <buffer> j gj
nnoremap <buffer> k gk
vnoremap <buffer> j gj
vnoremap <buffer> k gk

nnoremap <buffer> q     <cmd>q<cr>
nnoremap <buffer> <c-[> <cmd>q<cr>
