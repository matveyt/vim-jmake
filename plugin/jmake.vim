" Vim plugin to run 'make' asynchronously
" Maintainer:   matveyt
" Last Change:  2020 Sep 20
" License:      VIM License
" URL:          https://github.com/matveyt/vim-jmake

if exists('g:loaded_jmake')
    finish
endif
let g:loaded_jmake = 1

let s:save_cpo = &cpo
set cpo&vim

command! -bang -nargs=* Make call jmake#run(v:false, 'make', &makeprg, &errorformat,
    \ <q-bang>, <f-args>)
command! -bang -nargs=* Lmake call jmake#run(v:true, 'make', &makeprg, &errorformat,
    \ <q-bang>, <f-args>)
command! -bang -nargs=* Grep call jmake#run(v:false, 'grep', &grepprg, &grepformat,
    \ <q-bang>, <f-args>)
command! -bang -nargs=* Lgrep call jmake#run(v:true, 'grep', &grepprg, &grepformat,
    \ <q-bang>, <f-args>)

let &cpo = s:save_cpo
unlet s:save_cpo
