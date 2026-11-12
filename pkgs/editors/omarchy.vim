let s:config = empty($XDG_CONFIG_HOME) ? expand('~/.config') : $XDG_CONFIG_HOME
let s:file = s:config . '/omarchy/runtime/vim-theme.vim'
if !filereadable(s:file)
  finish
endif
execute 'source ' . fnameescape(s:file)
