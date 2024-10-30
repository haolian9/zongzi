if exists("b:current_syntax") | finish | endif

syn match qfName  "^[^|]*" nextgroup=qfBar
syn match qfBar   "|"      nextgroup=qfRow  contained
syn match qfRow   "[^|]*"  nextgroup=qfBar2 contained
syn match qfBar2  "|"      contained        contains=qfError
syn match qfError "error"  contained

hi def link qfName  Directory
hi def link qfRow   LineNr
hi def link qfError Error
hi def link qfBar2  qfBar

let b:current_syntax = "qf"

" vim: ts=8
