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
  if s:is_implicit_function_call()
    let [l, start] = searchpos('\m\k[?!]\=\s\+\%("\|-\d\|\k\|[({([]]\)', 'nb', line('.'))
    if &ft =~ '\m\<\%(ruby\|eruby\)\>'
      let [l, end] = searchpos('\m\%(\S\s\+\<do\>\|%>\|$\)', 'n', line('.'))
    elseif &ft =~ '\<coffee\>' && match(getline(line('.')), '\m\S\s\+->$') > -1
      let [l, end] = searchpos('\m\S\zs\s\+->$', 'n', line('.'))
    else
      let end = col('$') - 1
      let c = getline(line('.'))[-1:]
      if s:is_open(c, 0) && col('.') == end
        let s:stack = [c]
      endif
    endif
    call searchpair('\%(\%' . (start+1) . 'c\|[({[]\)', ',', '\%(\%' . end . 'c\|[]})]\)', direction . 'W', "s:skip(" . a:direction . ", " . (start+1) . ", " . end . ")", line('.'))
  else
    call searchpair('[({[]', ',', '[]})]', direction . 'W', "s:skip(" . a:direction . ")")
  endif
endfunction

function! s:skip(direction, ...)
  if a:0 && ((col('.') == a:2) || (col('.') == a:1))
    return 0
  endif
  let syn = synIDattr(synID(line("."), col("."), 0), "name")
  if syn =~? "string" || syn =~? "comment" || syn =~? "regex" || syn =~? "perlmatch" || syn =~? "perlsubstitution"
    return 1
  endif
  let c = s:getchar()
  let top = len(s:stack) > 0 ? s:stack[0] : ''
  if top == '' && !s:is_open(c, a:direction) && (!a:0 || c =~ ',')
    return 0
  elseif a:0 && c !~ '[](),{}[]' && a:2 == col('.')
    return 1
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

function! s:is_implicit_function_call()
  return &ft =~ '\m\<\%(ruby\|eruby\|coffee\)\>' && getline(line('.')) =~ '\m\k[?!]\=\s\+\%("\|-\d\|\k\+\>[?!]\=\s*\%([(\.]\)\@!\|[({[]]\)'
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
endfunction

function! s:Move(direction)
  let selection = &selection
  let &selection = "inclusive"
  let pos = getpos('.')
  let outer = s:OuterTextObject()
  call setpos('.', pos)
  let a = s:InnerTextObject()
  if a:direction
    call setpos('.', outer[2])
    call s:ArgMotion(a:direction)
  else
    call setpos('.', outer[1])
    if s:getchar() != ','
      call s:ArgMotion(a:direction)
    endif
  endif
  let b = s:InnerTextObject()
  call s:exchange(a, b)
  call s:ArgMotion(1)
  let &selection = selection
endfunction

function! s:Count(mapping, fn, ...)
  let operator = v:operator
  for i in range(v:count1)
    call call(a:fn, a:000)
  endfor
  if a:mapping != ''
    sil! call repeat#set("\<Plug>Argumentative_" . a:mapping . (operator == 'c' ? "\<c-r>." : ''), v:count1)
  endif
endfunction

function! s:exchange(a, b)
  let rv = getreg('a')
  let rt = getregtype('a')
  let vm = visualmode()
  let vs = getpos("'<")
  let ve = getpos("'>")
  let virtualedit = &virtualedit
  let &virtualedit = 'onemore'
  try
    if s:cmp(a:a[1], a:b[1]) < 0
      let x = a:a
      let y = a:b
      let adjust = 1
    else
      let x = a:b
      let y = a:a
      let adjust = 0
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
    let adj_bottom = [getpos("'["), getpos("']")]
    call setpos("'[", x[1])
    call setpos("']", x[2])
    norm! `[v`]"_d
    let @a = second
    norm! "aP
    let adj_top = [getpos("'["), getpos("']")]
    if adjust
      let l_delta = 0
      let c_delta1 = 0
      let c_delta2 = 0
      if x[2][1] == adj_bottom[0][1]
        let c_delta1 = adj_top[1][2] - x[2][2]
        if x[1][1] == x[2][1]
          let c_delta2 = c_delta1
        endif
      endif
      if adj_top[1][1] != x[2][1]
        let l_delta = adj_top[1][1] - x[2][1]
      endif
      call setpos("'[", [adj_bottom[0][0], adj_bottom[0][1] + l_delta, adj_bottom[0][2] + c_delta1, adj_bottom[0][3]])
      call setpos("']", [adj_bottom[1][0], adj_bottom[1][1] + l_delta, adj_bottom[1][2] + c_delta2, adj_bottom[1][3]])
    endif
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
    norm! `]
    call setreg('a', rv, rt)
    let &virtualedit = virtualedit
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
  if s:is_open(s:getchar(), 1)
    call s:ArgMotion(1)
    let ce = s:getchar()
    let end = getpos('.')
    call s:ArgMotion(0)
    let cs = s:getchar()
    let start = getpos('.')
  else
    call s:ArgMotion(0)
    let cs = s:getchar()
    let start = getpos('.')
    call s:ArgMotion(1)
    let ce = s:getchar()
    let end = getpos('.')
  endif
  if cs =~ '[{([]' || (cs == ',' && ce !~ '[])}]')
    call setpos('.', start)
    call search('\_.', 'W')
    let start = getpos('.')
  endif
  if ce =~ '[])}]' && !(s:is_implicit_function_call() && end[2] == col('$')-1)
    call setpos('.', end)
    call search('.', 'bW')
    let end = getpos('.')
  endif
  if cs =~ '[{([]' && ce =~ ','
    call setpos('.', end)
    call search(',\%(\_s\{-}\n\ze\s*\|\s\+\ze\)\S', 'ceW')
    let end = getpos('.')
  endif
  return ['v', start, end]
endfunction

function! s:InnerTextObject()
  let outer = s:OuterTextObject()
  call setpos('.', outer[1])
  call search('\S', 'W' . (s:getchar() != ',' ? 'c' : ''))
  let start = getpos('.')
  call setpos('.', outer[2])
  call search('\S\&[^,]', 'bW' . (s:getchar() != ',' ? 'c' : ''))
  let end = getpos('.')
  return ['v', start, end]
endfunction

function! s:getchar(...)
  return getline(line('.'))[col('.') + (a:0 ? a:1 : 0) - 1] 
endfunction

function! s:PlugMap(mode, lhs, rhs)
  let plugmap = '<Plug>Argumentative_' . a:rhs
  if !hasmapto(plugmap, a:mode)
    exe a:mode . 'map ' . a:lhs . ' ' . plugmap
  endif
endfunction

function! s:VisualTextObject(fn)
  let ms = getpos("'[")
  let me = getpos("']")
  let vs = getpos("'<")
  let ve = getpos("'>")

  call setpos(".", vs)
  if s:getchar() == ','
    call search('.', 'W')
  endif

  try
    let obj = call(a:fn, [])

    if s:needs_to_expand(vs, ve, obj, a:fn)
      call setpos(".", ve)
      call s:ArgMotion(1)
      let c = s:getchar()
      while c !~ '[])}]'
        call s:ArgMotion(1)
        let c = s:getchar()
      endwhile
      normal! l
      let possible = call(a:fn, [])
      if s:contained(possible, obj)
        let obj = possible
      endif
    endif

    call setpos("'[", obj[1])
    call setpos("']", obj[2])
    exe 'norm! `[' . obj[0] . '`]'
    if &selection ==# 'exclusive'
      let virtualedit = &virtualedit
      let &virtualedit = "all"
      exe "norm! \<esc>gvl"
      let &virtualedit = virtualedit
    endif
  finally
    call setpos("'[", ms)
    call setpos("']", me)
  endtry
endfunction

function! s:needs_to_expand(vs, ve, obj, fn)
  " single character selections are not expanable
  if s:cmp(a:vs, a:ve) == 0
    return 0
  endif

  " object w/ same boundries as selction should expand
  if s:cmp(a:vs, a:obj[1]) == 0 && s:cmp(a:ve, a:obj[2]) == 0
    return 1
  endif

  " move cursor to opposite end of selection and repeat text object
  call setpos(".", a:ve)
  let obj = call(a:fn, [])
  call setpos(".", a:vs)

  " objects at different locations should expand
  if s:cmp(obj[1], a:obj[1]) != 0 || s:cmp(obj[2], a:obj[2]) != 0
    return 1
  endif

  return 0
endfunction

" region a contains region b
function! s:contained(a, b)
  return s:cmp(a:a[1], a:b[1]) <= 0 && s:cmp(a:b[2], a:a[2]) <= 0
endfunction

noremap <script> <silent> <Plug>Argumentative_Prev :<c-u>call <SID>Count("", "\<SID>ArgMotion", 0)<cr>
noremap <script> <silent> <Plug>Argumentative_Next :<c-u>call <SID>Count("", "\<SID>ArgMotion", 1)<cr>
noremap <script> <silent> <Plug>Argumentative_XPrev :<c-u>call <SID>Count("", "\<SID>ArgMotion", 0)<cr>m'gv``
noremap <script> <silent> <Plug>Argumentative_XNext :<c-u>call <SID>Count("", "\<SID>ArgMotion", 1)<cr>m'gv``
noremap <script> <silent> <Plug>Argumentative_MoveLeft :<c-u>call  <SID>Count("MoveLeft", "\<SID>MoveLeft")<cr>
noremap <script> <silent> <Plug>Argumentative_MoveRight :<c-u>call <SID>Count("MoveRight", "\<SID>MoveRight")<cr>

noremap <silent> <SID>Argumentative_InnerTextObject :<c-u>call <SID>VisualTextObject("\<SID>InnerTextObject")<cr>
noremap <silent> <SID>Argumentative_OuterTextObject :<c-u>call <SID>VisualTextObject("\<SID>OuterTextObject")<cr>

noremap <script> <silent> <Plug>Argumentative_InnerTextObject :<c-u>call <SID>VisualTextObject("\<SID>InnerTextObject")<cr>
noremap <script> <silent> <Plug>Argumentative_OuterTextObject :<c-u>call <SID>VisualTextObject("\<SID>OuterTextObject")<cr>
noremap <script> <silent> <Plug>Argumentative_OpPendingInnerTextObject :exe "normal v\<SID>Argumentative_InnerTextObject"<cr>
noremap <script> <silent> <Plug>Argumentative_OpPendingOuterTextObject :exe "normal v\<SID>Argumentative_OuterTextObject"<cr>

if !exists("g:argumentative_no_mappings") || ! g:argumentative_no_mappings
  call s:PlugMap('n', '[,', 'Prev')
  call s:PlugMap('n', '],', 'Next')
  call s:PlugMap('o', '[,', 'Prev')
  call s:PlugMap('o', '],', 'Next')
  call s:PlugMap('x', '[,', 'XPrev')
  call s:PlugMap('x', '],', 'XNext')
  call s:PlugMap('n', '<,', 'MoveLeft')
  call s:PlugMap('n', '>,', 'MoveRight')

  " Simple text object mappings
  call s:PlugMap('x', 'i,', 'InnerTextObject')
  call s:PlugMap('x', 'a,', 'OuterTextObject')
  call s:PlugMap('o', 'i,', 'OpPendingInnerTextObject')
  call s:PlugMap('o', 'a,', 'OpPendingOuterTextObject')
endif
