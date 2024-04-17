let g:bullets#bullet_marks_ul = '[-+*]'
let g:bullets#bullet_marks_ol = '\d\+\.'

let g:bullets#renumber_on_change = get(g:, 'bullets#renumber_on_change', v:false)
let g:bullets#enable_filetypes = get(g:, 'bullets#enable_filetypes', [ 'markdown', 'rmd' ])

fu! s:ends_with_colon(lnum = '.')
    let line = getline(a:lnum)
    let last_char = strcharpart(line, strcharlen(line) - 1)
    return last_char == ':' || last_char == '：'
endf

fu! s:end_of_line()
    if mode() == 'i'
        return col(".") == col("$")
    elseif mode() == 'n'
        return col(".") == col("$") - 1
    else
        echoerr 'not supported: ' mode()
    endif
endf

fu! s:is_empty_bullet(lnum = '.')
    return getline(a:lnum) =~# '^\s*\(' . g:bullets#bullet_marks_ol . '\|'
        \ . g:bullets#bullet_marks_ul . '\)\s*$'
endf

fu! s:is_bullet(lnum = '.')
    return getline(a:lnum) =~# '^\s*\(' . g:bullets#bullet_marks_ol . '\|'
        \ . g:bullets#bullet_marks_ul . '\)\(\s*$\|\s\+\S\)'
endf

" linetype['type']: normal(10), ul bullet(1), ol bullet(2)
fu! s:line_type(lnum = '.')
    let linetype = { 'type': 10, 'empty_bullet': v:false, 'marker': '' } " default: plain line
    let line = getline(a:lnum)
    if line =~# '^\s*\(' . g:bullets#bullet_marks_ol . '\|' . g:bullets#bullet_marks_ul . '\)\s*$'
        let linetype['empty_bullet'] = v:true
    endif
    if line =~# '^\s*' . g:bullets#bullet_marks_ol . '\(\s*$\|\s\+\S\)'
        let linetype['type'] = 2
    elseif line =~# '^\s*' . g:bullets#bullet_marks_ul . '\(\s*$\|\s\+\S\)'
        let linetype['type'] = 1
    endif
    if linetype['type'] == 1 || linetype['type'] == 2
        let linetype['marker'] = matchlist(line, '^\s*\(' . g:bullets#bullet_marks_ol . '\|' . g:bullets#bullet_marks_ul . '\)\(\s*$\|\s\+\S\)')[1]
    endif
    return linetype
endf

fu! s:line_indent(lnum = '.')
    return match(getline(a:lnum), '\S')
endf

fu! s:reorder(lnum = '.', start_line = 0)
    let l:ol_id = reltimestr(reltime())[-3:]

    let lnum = type(a:lnum) == 0 ? a:lnum : line(a:lnum)

    let first_bullet_lnum = 0
    if a:start_line != 0
        let first_bullet_lnum = a:start_line
    else
        let i = lnum
        while getline(i - 1) != ''
            let i = i - 1
            if s:line_type(i)['type'] == 2
                let first_bullet_lnum = i
            endif
        endwhile
    endif

    let linenr = first_bullet_lnum
    let linetype = s:line_type(linenr)
    let order_number = 1

    let indent = s:line_indent(linenr)

    while getline(linenr) != ''
        if s:line_indent(linenr) == indent
            if linetype['type'] == 2
                if matchlist(getline(linenr), '\s*\(\d\+\)\.')[1] != order_number
                    call setline(linenr, substitute(getline(linenr), '^\s*\zs\d\+\ze\.', order_number, ''))
                    " echomsg "\tline " . linenr . ' is set to ' . order_number
                endif
                let order_number = order_number + 1
            endif
        elseif s:line_indent(linenr) > indent
            let linenr = s:reorder(linenr, linenr)
        else
            " echomsg '[' . l:ol_id . ']end at line ' . (linenr - 1)
            return linenr - 1
        endif

        let linenr = linenr + 1
        let linetype = s:line_type(linenr)
    endwhile

    " echomsg '[' . l:ol_id . ']end at line ' . linenr
    return linenr
endf

fu! s:new_bullet(insert_over = v:false)
    if mode() != 'i'
        startinsert!
    endif

    if !s:is_bullet()
        let key = nvim_replace_termcodes('<CR>', v:true, v:false, v:true)
        call nvim_feedkeys(key, 'n', v:false)
        return v:false
    endif

    let lnum = line('.')
    let line = getline(lnum)
    let ltype = s:line_type(lnum)

    if ltype['empty_bullet'] == v:true
        call setline(lnum, '')
        return
    endif

    let marker = ltype['marker']
    if ltype['type'] == 2
        if a:insert_over
            let marker = (marker[:-2] - 1 > 0 ? marker[:-2] - 1 : 1) . '.'
        else
            let marker = marker[:-2] + 1 . '.'
        endif
    endif

    if s:end_of_line()
        call append(a:insert_over ? lnum - 1 : lnum,
                    \ repeat(' ', s:line_indent(lnum) +
                    \   (s:ends_with_colon(lnum) ? shiftwidth() : 0))
                    \ . marker . ' '
                    \ )
    else
        call setline('.', line[:col('.')-2])
        call append(a:insert_over ? lnum - 1 : lnum,
                    \ repeat(' ', s:line_indent(lnum) +
                    \   (s:ends_with_colon(lnum) ? shiftwidth() : 0))
                    \ . marker . ' '
                    \ . line[col('.')-1:]
                    \ )
    endif

    call cursor(a:insert_over ? lnum : lnum + 1,
                \ s:line_indent(lnum) + 2 + strlen(marker)
                \   + (s:ends_with_colon(lnum) ? shiftwidth() : 0)
                \ )

    if ltype['type'] == 2 && g:bullets#renumber_on_change
        call s:reorder()
    endif
endf

inoremap <buffer> <CR> <Cmd>call <SID>new_bullet()<CR>
inoremap <buffer> <S-CR> <Cmd>call <SID>new_bullet(v:true)<CR>
inoremap <buffer> <C-CR> <ESC>A<Cmd>call <SID>new_bullet()<CR>
inoremap <buffer> <C-S-CR> <ESC>A<Cmd>call <SID>new_bullet(v:true)<CR>
nnoremap <buffer> o <Cmd>call <SID>new_bullet()<CR>
nnoremap <buffer> O <Cmd>call <SID>new_bullet(v:true)<CR>

nnoremap <buffer> <C-'> <Cmd>call <SID>reorder()<CR>
