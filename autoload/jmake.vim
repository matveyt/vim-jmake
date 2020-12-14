" Vim plugin to run :make and :grep asynchronously
" Maintainer:   matveyt
" Last Change:  2020 Dec 14
" License:      VIM License
" URL:          https://github.com/matveyt/vim-jmake

let s:save_cpo = &cpo
set cpo&vim

function s:chdir(dir) abort
    if exists('*chdir')
        return chdir(a:dir)
    elseif has('nvim')
        let l:cd = haslocaldir() ? 'lcd' : haslocaldir(-1, 0) ? 'tcd' : 'cd'
    else
        let l:cd = haslocaldir() == 1 ? 'lcd' : haslocaldir() == 2 ? 'tcd' : 'cd'
    endif

    let l:old = getcwd()
    try | execute l:cd fnameescape(a:dir)
    finally | return l:old
    endtry
endfunction

function s:iconv(expr, from) abort
    if empty(a:from)
        if type(a:expr) == v:t_list
            return copy(a:expr)
        else
            return split(a:expr, "\n", 1)
        endif
    else
        if type(a:expr) == v:t_list
            return map(copy(a:expr), {_, v -> iconv(v, a:from, &enc)})
        else
            return split(iconv(a:expr, a:from, &enc), "\n", 1)
        endif
    endif
endfunction

function s:qfopen(local, name, qfid, doau) abort
    let l:ours = {'id': a:qfid, 'nr': 0}
    let l:curr = {'nr': 0}
    if a:local
        let l:delta = getloclist(0, l:ours).nr - getloclist(0, l:curr).nr
    else
        let l:delta = getqflist(l:ours).nr - getqflist(l:curr).nr
    endif

    if l:delta
        execute printf('silent %s%s %d', a:local ? 'l' : 'c',
            \ l:delta > 0 ? 'newer' : 'older', abs(l:delta))
    endif
    if a:doau
        execute 'silent doautocmd <nomodeline> QuickFixCmdPost' a:name
    endif
    execute a:local ? 'lopen' : 'copen'
endfunction

function s:jmake_alloc(name, winid) abort
    let l:jmake = {}
    let l:jmake.name = (a:winid > 0 ? 'l' : '') . a:name
    let l:jmake.winid = a:winid
    let l:jmake.job = v:null
    let l:jmake.cmd = v:null
    let l:jmake.qfid = 0
    let l:jmake.efm = v:null
    let l:jmake.enc = v:null
    let l:jmake.cwd = v:null
    return l:jmake
endfunction

function s:jmake_start(jmake) abort
    if has('nvim')
        let a:jmake.job = jobstart([&sh, &shcf, a:jmake.cmd], {
            \ 'on_stdout': funcref('s:jmake_on_data', [a:jmake]),
            \ 'on_stderr': funcref('s:jmake_on_data', [a:jmake]),
            \ 'on_exit': funcref('s:jmake_on_exit', [a:jmake])
        \ })
    elseif has('job')
        let a:jmake.job = job_start([&sh, &shcf, a:jmake.cmd], {
            \ 'out_cb': funcref('s:jmake_on_data', [a:jmake]),
            \ 'err_cb': funcref('s:jmake_on_data', [a:jmake]),
            \ 'exit_cb': funcref('s:jmake_on_exit', [a:jmake])
        \ })
    endif
    return s:jmake_running(a:jmake)
endfunction

function s:jmake_running(jmake) abort
    if empty(a:jmake.job)
        return 0
    elseif has('nvim')
        return jobwait([a:jmake.job], 0)[0] == -1
    elseif has('job')
        return job_status(a:jmake.job) is# 'run'
    endif
endfunction

function s:jmake_stop(jmake) abort
    if empty(a:jmake.job)
        return
    elseif has('nvim')
        call jobstop(a:jmake.job)
    elseif has('job')
        call job_stop(a:jmake.job)
    endif
endfunction

function s:jmake_on_data(jmake, id, data, ...) abort
    let l:cwd = s:chdir(a:jmake.cwd)

    let l:what = {}
    let l:what.id = a:jmake.qfid
    let l:what.efm = a:jmake.efm
    let l:what.lines = s:iconv(a:data, a:jmake.enc)

    if a:jmake.winid > 0
        call setloclist(a:jmake.winid, [], 'a', l:what)
    else
        call setqflist([], 'a', l:what)
    endif

    call s:chdir(l:cwd)
endfunction

function s:jmake_on_exit(jmake, id, status, ...) abort
    let l:local = a:jmake.winid > 0

    let l:what = {}
    let l:what.id = a:jmake.qfid
    let l:what.efm = a:jmake.efm
    let l:what.lines = [printf('[Exited with code %d]', a:status)]

    if l:local
        if !win_gotoid(a:jmake.winid)
            return
        endif
        call setloclist(0, [], 'a', l:what)
    else
        call setqflist([], 'a', l:what)
    endif

    call s:qfopen(l:local, a:jmake.name, a:jmake.qfid, 1)
endfunction

function! jmake#run(local, name, prog, efm, ...) abort
    if a:local
        if !exists('w:j'..a:name)
            let w:j{a:name} = s:jmake_alloc(a:name, win_getid())
        endif
        let l:jmake = w:j{a:name}
    else
        if !exists('s:j'..a:name)
            let s:j{a:name} = s:jmake_alloc(a:name, 0)
        endif
        let l:jmake = s:j{a:name}
    endif

    let l:is_running = s:jmake_running(l:jmake)
    let l:args = filter(copy(a:000), {_, v -> !empty(v)})

    if get(l:args, 0) is# '!'
        if l:is_running
            call s:jmake_stop(l:jmake)
        else
            echo a:name 'is not running'
        endif
        return
    elseif get(l:args, 0) is# '?' || l:is_running
        if l:jmake.qfid > 0
            call s:qfopen(a:local, l:jmake.name, l:jmake.qfid, 0)
        else
            echo 'Nothing to see here... move along!'
        endif
        return
    endif

    if match(a:prog, '\$\*') >= 0
        let l:args = split(substitute(a:prog, '\$\*', join(l:args), 'g'))
    else
        call extend(l:args, split(a:prog), 0)
    endif
    let l:jmake.cmd = join(map(l:args, {_, v -> v =~# '^[%#<]' ? expand(v) : v }))

    execute 'silent doautocmd <nomodeline> QuickFixCmdPre' l:jmake.name

    if &autowrite || &autowriteall
        silent! wall
    endif

    let l:what = {'nr': '$', 'id': 0, 'title': l:jmake.cmd}
    if a:local
        call setloclist(0, [], ' ', l:what)
        let l:jmake.qfid = getloclist(0, l:what).id
    else
        call setqflist([], ' ', l:what)
        let l:jmake.qfid = getqflist(l:what).id
    endif

    let l:jmake.efm = a:efm
    let l:jmake.enc = &makeencoding
    let l:jmake.cwd = getcwd()
    if !s:jmake_start(l:jmake)
        echo 'Starting [' . l:jmake.cmd . '] failed'
    endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
