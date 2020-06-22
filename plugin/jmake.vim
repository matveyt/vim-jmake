" Vim plugin to run 'make' asynchronously
" Maintainer:   matveyt
" Last Change:  2020 Jun 16
" License:      VIM License
" URL:          https://github.com/matveyt/vim-jmake

if exists('g:loaded_jmake')
    finish
endif
let g:loaded_jmake = 1

command! -bang -nargs=* Make call jmake#run(v:false, <q-bang>, <f-args>)
command! -bang -nargs=* Lmake call jmake#run(v:true, <q-bang>, <f-args>)
