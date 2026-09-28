#!/usr/bin/env bash
set -euo pipefail

: "${HYPRCHROMA_PACKAGE:?HYPRCHROMA_PACKAGE must point to a built hyprchroma package}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

lib="$tmp/lib"
config="$tmp/config"
state="$tmp/state"
mkdir -p "$lib" "$config" "$state" "$tmp/home"
export HOME="$tmp/home"

cp "$HYPRCHROMA_PACKAGE/lib/hyprchroma/hyprchroma-editors" "$lib/"
cp "$HYPRCHROMA_PACKAGE/lib/hyprchroma/hyprchroma-state" "$lib/"
python_bin=$(command -v python3)
sed -i "1c#!$python_bin" "$lib/hyprchroma-editors" "$lib/hyprchroma-state"

cat > "$lib/hyprchroma-palette" <<'EOF'
#!/bin/sh
cat <<'PALETTE'
mode	light
background	#101820
foreground	#f0f0e0
dark_background	#080c10
lighter_background	#304050
selection	#304050
accent	#40c0a0
muted	#809090
red	#e06060
green	#60c080
yellow	#d0b060
blue	#6090d0
magenta	#c080d0
bright_red	#ff7070
cyan	#70d0d0
PALETTE
EOF
chmod 755 "$lib/hyprchroma-palette"

run_renderer() {
  XDG_CONFIG_HOME="$config" \
    XDG_STATE_HOME="$state" \
    HOME="$tmp/home" \
    "$lib/hyprchroma-editors"
}

run_renderer

test -f "$config/omarchy/runtime/neovim-theme.lua"
test -f "$config/omarchy/runtime/vim-theme.vim"
test -f "$state/hyprchroma/editors.json"
grep -Fq 'Normal = { fg = "#f0f0e0", bg = "#101820" }' "$config/omarchy/runtime/neovim-theme.lua"
grep -Fq 'set background=light' "$config/omarchy/runtime/vim-theme.vim"
grep -Fq 'set termguicolors' "$config/omarchy/runtime/vim-theme.vim"
grep -Fq 'highlight Function guifg=#6090d0' "$config/omarchy/runtime/vim-theme.vim"
grep -Fq '"neovim": "generated"' "$state/hyprchroma/editors.json"

nvim --headless -u NONE \
  -c "lua local t=dofile('$config/omarchy/runtime/neovim-theme.lua'); for group, highlights in pairs(t.highlights) do vim.api.nvim_set_hl(0, group, highlights) end; local h=vim.api.nvim_get_hl(0, {name='Normal'}); assert(string.format('#%06x', h.fg) == '#f0f0e0')" \
  -c 'qa!'
vim -Nu NONE -n -es \
  -c "source $config/omarchy/runtime/vim-theme.vim" \
  -c "if execute('highlight Normal') !~ '#f0f0e0' | cquit | endif" \
  -c 'qa!'

before=$(sha256sum \
  "$config/omarchy/runtime/neovim-theme.lua" \
  "$config/omarchy/runtime/vim-theme.vim" \
  "$state/hyprchroma/editors.json")
run_renderer
test "$before" = "$(sha256sum \
  "$config/omarchy/runtime/neovim-theme.lua" \
  "$config/omarchy/runtime/vim-theme.vim" \
  "$state/hyprchroma/editors.json")"

echo "editor runtime test passed"
