" Vim syntax file
" Language:    Quickfix window
" Maintainer:    Bram Moolenaar <Bram@vim.org>
" Last change:    2001 Jan 15

if exists("b:current_syntax") | finish | endif

syn match qfFileName   "^[^|]*" nextgroup=qfSeparator
syn match qfSeparator  "|"      nextgroup=qfLineNr     contained
syn match qfLineNr     "[^|]*"  nextgroup=qfSeparator2 contained
syn match qfSeparator2 "|"      contained              contains=qfError
syn match qfError      "error"  contained

hi def link qfFileName   Directory
hi def link qfLineNr     LineNr
hi def link qfError      Error
hi def link qfSeparator2 qfSeparator

let b:current_syntax = "qf"

" vim: ts=8
