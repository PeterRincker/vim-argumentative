if exists('g:loaded_argumentative') || &cp || v:version < 700
  finish
endif
let g:loaded_argumentative = 1

let s:pairs = {}
let s:pairs['('] = ')'
let s:pairs['{'] = '}'
let s:pairs['['] = ']'
let s:pairs[')'] = '('
let s:pairs['}'] = '{'
let s:pairs[']'] = '['

" ArgMotion
" Move to the next boundry. Takes nesting into account.
" a:direction: int
"   0 for backward, otherwise forwards
function! s:ArgMotion(direction)
  let direction = a:direction ? '' : 'b'
  let s:stack = []
  call searchpair('[({[]', ',', '[]})]', direction . 'W', "s:skip(" . a:direction . ")")
endfunction

function! s:skip(direction)
  let syn = synIDattr(synID(line("."), col("."), 0), "name")
  if syn =~? "string" || syn =~? "comment" || syn =~? "regex" || syn =~? "perlmatch" || syn =~? "perlsubstitution"
    return 1
  endif
  let c = s:getchar()
  let top = len(s:stack) > 0 ? s:stack[0] : ''
  if top == '' && !s:is_open(c, a:direction)
    return 0
  elseif c =~ '[](){}[]'
    if top == s:get_pair(c)
      call remove(s:stack, 0)
      return 1
    else
      call insert(s:stack, c, 0)
    endif
  endif
  return len(s:stack) > 0
endfunction

function! s:get_pair(c)
  return get(s:pairs, a:c, '')
endfunction

function! s:is_open(c, direction)
  return a:direction ? a:c =~ '[({[]' : a:c =~ '[])}]'
endfunction

function! s:MoveLeft()
  call s:Move(0)
endfunction

function! s:MoveRight()
  call s:Move(1)
  let o = s:OuterTextObject()
  call setpos('.', o[2])
  call search('.', 'W')
  let a = s:InnerTextObject()
  call setpos('.', a[1])
endfunction

function! s:Move(direction)
  let pos = getpos('.')
  let outer = s:OuterTextObject()
  call setpos('.', pos)
  let a = s:InnerTextObject()
  if a:direction
    call setpos('.', outer[2])
    call s:ArgMotion(a:direction)
    if !s:is_open(s:getchar(), a:direction)
      call search('.', 'bW')
    endif
  else
    call setpos('.', outer[1])
    call s:ArgMotion(a:direction)
  endif
  let b = s:InnerTextObject()
  call s:exchange(a, b)
endfunction

function! s:Count(mapping, fn, ...)
  for i in range(v:count1)
    call call(a:fn, a:000)
  endfor
  if a:mapping != ''
    sil! call repeat#set("\<Plug>Argumentative_" . a:mapping, v:count1)
  endif
endfunction

function! s:exchange(a, b)
  let rv = getreg('a')
  let rt = getregtype('a')
  let vm = visualmode()
  let vs = getpos("'<")
  let ve = getpos("'>")
  try
    if s:cmp(a:a[1], a:b[1]) < 0
      let x = a:a
      let y = a:b
    else
      let x = a:b
      let y = a:a
    endif
    call setpos("'[", x[1])
    call setpos("']", x[2])
    norm! `[v`]"ay
    let first = @a
    call setpos("'[", y[1])
    call setpos("']", y[2])
    norm! `[v`]"ad
    let second = @a
    let @a = first
    norm! "aP
    call setpos("'[", x[1])
    call setpos("']", x[2])
    norm! `[v`]"_d
    let @a = second
    norm! "aP
  finally
    let ms = getpos("'[")
    let me = getpos("']")
    if vm != ''
      call setpos("'[", vs)
      call setpos("']", ve)
      exe "norm! `[" . vm[0] . "`]\<esc>"
    endif
    call setpos("'[", ms)
    call setpos("']", me)
    norm! `[
    call setreg('a', rv, rt)
  endtry
endfunction

function! s:cmp(a, b)
  for i in range(len(a:a))
    if a:a[i] < a:b[i]
      return -1
    elseif a:a[i] > a:b[i]
      return 1
    endif
  endfor
  return 0
endfunction

function! s:OuterTextObject()
  let c = s:getchar()
  if !s:is_open(c, 1) && c != ','
    call s:ArgMotion(1)
    let save = getpos('.')
    if s:getchar() =~ '[])}]'
      call search('.', 'bW')
    endif
    let end = getpos('.')
    call setpos('.', save)
    call s:ArgMotion(0)
    if s:getchar() =~ '[({,[]'
      call search('.', 'W')
    endif
    let start = getpos('.')
  else
    call s:ArgMotion(0)
    if s:getchar() =~ '[({,[]'
      call search('.', 'W')
    endif
    let start = getpos('.')
    call s:ArgMotion(1)
    if s:getchar() =~ '[])}]'
      call search('.', 'bW')
    endif
    let end = getpos('.')
  endif
  return ['v', start, end]
endfunction

function! s:InnerTextObject(...)
  let c = s:getchar()
  if !s:is_open(c, 1) && c != ','
    call s:ArgMotion(1)
    let outer_end = getpos('.')
    if s:getchar() !~ '\w'
      call search('\S', 'b')
    endif
    let end = getpos('.')
    call setpos('.', outer_end)
    call s:ArgMotion(0)
    if s:getchar() !~ '\w'
      call search('\S')
    endif
    let start = getpos('.')
  else
    call s:ArgMotion(0)
    let outer_start = getpos('.')
    if s:getchar() !~ '\w'
      call search('\S')
    endif
    let start = getpos('.')
    call setpos('.', outer_start)
    call s:ArgMotion(1)
    if s:getchar() !~ '\w'
      call search('\S', 'b')
    endif
    let end = getpos('.')
  endif
  return ['v', start, end]
endfunction

function! s:getchar(...)
  return getline(line('.'))[col('.') + (a:0 ? a:1 : 0) - 1] 
endfunction

function! s:PlugMap(mode, lhs, rhs)
  if !hasmapto(a:lhs, a:mode)
    exe a:mode . 'map ' . a:lhs . ' <Plug>Argumentative_' . a:rhs
  endif
endfunction

function! s:VisualTextObject(fn)
  let ms = getpos("'[")
  let me = getpos("']")
  try
    let obj = call(a:fn, [])
    call setpos("'[", obj[1])
    call setpos("']", obj[2])
    exe 'norm! `[' . obj[0] . '`]'
  finally
    call setpos("'[", ms)
    call setpos("']", me)
  endtry
endfunction

map <SID>xx <SID>xx
let s:sid = substitute(maparg("<SID>xx"),'xx$','', '')
unmap <SID>xx

noremap <script> <silent> <Plug>Argumentative_Prev :<c-u>call <SID>Count("", "\<SID>ArgMotion", 0)<cr>
noremap <script> <silent> <Plug>Argumentative_Next :<c-u>call <SID>Count("", "\<SID>ArgMotion", 1)<cr>
noremap <script> <silent> <Plug>Argumentative_OPrev :<c-u>call <SID>Count("", "\<SID>ArgMotion", 0)<cr>
noremap <script> <silent> <Plug>Argumentative_ONext :<c-u>call <SID>Count("", "\<SID>ArgMotion", 1)<cr>
noremap <script> <silent> <Plug>Argumentative_MoveLeft :<c-u>call  <SID>Count("MoveLeft", "\<SID>MoveLeft")<cr>
noremap <script> <silent> <Plug>Argumentative_MoveRight :<c-u>call <SID>Count("MoveRight", "\<SID>MoveRight")<cr>

noremap <script> <silent> <Plug>Argumentative_InnerTextObject :<c-u>call <SID>VisualTextObject("\<SID>InnerTextObject")<cr>
noremap <script> <silent> <Plug>Argumentative_OuterTextObject :<c-u>call <SID>VisualTextObject("\<SID>OuterTextObject")<cr>

call s:PlugMap('n', '[,', 'Prev')
call s:PlugMap('n', '],', 'Next')
call s:PlugMap('o', '[,', 'Prev')
call s:PlugMap('o', '],', 'Next')
call s:PlugMap('n', '<,', 'MoveLeft')
call s:PlugMap('n', '>,', 'MoveRight')

" try my own txtobj plugin
silent! call txtobj#map('a,', s:sid . "OuterTextObject")
silent! call txtobj#map('i,', s:sid . "InnerTextObject")

" try Kana's textobj-user plugin
if maparg('a,', 'v') == ''
  silent! call textobj#user#plugin('argumentative', {
        \      '-': {
        \        '*sfile*': expand('<sfile>:p'),
        \        'select-a': "a,",  '*select-a-argument*': 's:OuterTextObject',
        \        'select-i': "i,",  '*select-i-argument*': 's:InnerTextObject'
        \      }
        \    })
endif

" Simple text object mappings
if maparg('a,', 'v') == ''
  xmap i, <Plug>Argumentative_InnerTextObject
  xmap a, <Plug>Argumentative_OuterTextObject
  omap i, :normal vi,<cr>
  omap a, :normal va,<cr>
endif
