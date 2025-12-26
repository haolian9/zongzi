if exists("b:current_syntax") | finish | endif

" We need nocompatible mode in order to continue lines with backslashes.
" Original setting will be restored.
let s:cpo_save = &cpo
set cpo&vim

"""""""""" fancy start

syn keyword WikiTodo todo
syn keyword WikiTodo done

" [[path/name]]
syn match WikiPath  "\[\[[^]]\+\/"ms=s+2 contained conceal
syn match WikiName  "[^[/]\+\]\]"me=e-2  contained
syn match WikiEntry "\[\[.\+\]\]"        contains=WikiPath,WikiName

hi def link WikiTodo  Todo
hi def link WikiEntry Operator
hi def link WikiPath  String
hi def link WikiName  Normal

"""""""""" fancy end

let b:current_syntax = "wiki"

let &cpo = s:cpo_save
unlet s:cpo_save
