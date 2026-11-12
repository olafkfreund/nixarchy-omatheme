if exists('g:loaded_nixarchy_theme_bridge')
  finish
endif
let g:loaded_nixarchy_theme_bridge = 1
let s:config = empty($XDG_CONFIG_HOME) ? expand('~/.config') : $XDG_CONFIG_HOME
let s:file = s:config . '/omarchy/runtime/vim-theme.vim'
let s:applied = filereadable(s:file) ? readfile(s:file) : []
let s:pending = 0

function! s:apply() abort
  if !filereadable(s:file)
    let s:pending = 0
    return
  endif
  try
    let v:errmsg = ''
    silent! colorscheme omarchy
    if empty(v:errmsg) && exists('g:colors_name') && g:colors_name ==# 'omarchy'
      let s:applied = readfile(s:file)
      let s:pending = 0
      return
    endif
  catch
  endtry
  let s:pending = 1
endfunction

function! s:startup() abort
  if exists('g:colors_name')
    return
  endif
  let id = synIDtrans(hlID('Normal'))
  for mode in ['gui', 'cterm']
    if !empty(synIDattr(id, 'fg', mode)) || !empty(synIDattr(id, 'bg', mode))
      return
    endif
  endfor
  call s:apply()
endfunction

function! s:watch(timer) abort
  if !filereadable(s:file)
    return
  endif
  try
    let current = readfile(s:file)
  catch
    let s:pending = 1
    return
  endtry
  if current !=# s:applied || s:pending
    if mode() ==# 'c'
      let s:pending = 1
    else
      call s:apply()
    endif
  endif
endfunction

command! OmarchyThemeReload call <SID>apply()
augroup nixarchy_theme_bridge
  autocmd!
  autocmd VimEnter * call <SID>startup()
augroup END
if v:vim_did_enter
  call s:startup()
endif
if exists('*timer_start')
  let s:timer = timer_start(500, function('<SID>watch'), {'repeat': -1})
  autocmd nixarchy_theme_bridge VimLeavePre * call timer_stop(s:timer)
endif
