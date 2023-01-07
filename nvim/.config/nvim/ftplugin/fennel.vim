let b:did_ftplugin = 1

setl suffixesadd=.fnl
setl commentstring=;;\ %s

nnoremap <buffer> <leader>p <cmd>lua require'windmill'.preview_fennel()<cr>
vnoremap <buffer> K :lua require'help'.luaref()<cr>
