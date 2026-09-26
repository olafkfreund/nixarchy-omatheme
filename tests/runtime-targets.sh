#!/usr/bin/env bash
set -euo pipefail

: "${HYPRCHROMA_PACKAGE:?HYPRCHROMA_PACKAGE must point to a built hyprchroma package}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

lib="$tmp/lib"
config="$tmp/config"
state="$tmp/state"
home="$tmp/home"
bin="$tmp/bin"
mkdir -p "$lib" "$config/omarchy/runtime" "$state" "$home" "$bin"

cp "$HYPRCHROMA_PACKAGE/lib/hyprchroma/hyprchroma-shell" "$lib/"
cp "$HYPRCHROMA_PACKAGE/lib/hyprchroma/hyprchroma-terminals" "$lib/"
cp "$HYPRCHROMA_PACKAGE/lib/hyprchroma/hyprchroma-state" "$lib/"
bash_bin=$(command -v bash)
python_bin=$(command -v python3)
sed -i "1c#!$python_bin" "$lib/hyprchroma-shell" "$lib/hyprchroma-state"
sed -i "1c#!$bash_bin" "$lib/hyprchroma-terminals"

cat > "$lib/hyprchroma-palette" <<'EOF'
#!/bin/sh
set -euo pipefail
cat "$HYPRCHROMA_FIXTURE"
EOF
chmod 755 "$lib/hyprchroma-palette"

for command in starship bash zsh fish; do
  printf '#!/bin/sh\nexit 0\n' > "$bin/$command"
  chmod 755 "$bin/$command"
done
sed -i "1c#!$bash_bin" "$lib/hyprchroma-palette" "$bin"/*

cat > "$tmp/palette.one" <<'EOF'
background	#101820
foreground	#f0f0e0
darker_background	#080c10
bright_foreground	#ffffff
selection	#304050
selection_foreground	#ffffff
accent	#40c0a0
muted	#809090
red	#e06060
green	#60c080
yellow	#d0b060
blue	#6090d0
magenta	#c080d0
bright_red	#ff7070
bright_green	#70e090
bright_yellow	#f0d070
EOF

cat > "$tmp/palette.two" <<'EOF'
background	#201018
foreground	#f8e8f0
darker_background	#10080c
bright_foreground	#ffffff
selection	#503040
selection_foreground	#ffffff
accent	#e080c0
muted	#a090a0
red	#e07080
green	#70c090
yellow	#e0b070
blue	#8090e0
magenta	#e090d0
bright_red	#ff8090
bright_green	#80e0a0
bright_yellow	#f0d080
EOF

cat > "$config/omarchy/runtime/starship.base.toml" <<'EOF'
format = "$directory"
palette = "user"
EOF

cat > "$config/alacritty.toml" <<'EOF'
[general]
import = ["~/.config/alacritty/theme-active.toml"]
EOF

run_renderers() {
  HYPRCHROMA_FIXTURE="$1" \
    XDG_CONFIG_HOME="$config" \
    XDG_STATE_HOME="$state" \
    HOME="$home" \
    PATH="$bin:$PATH" \
    "$lib/hyprchroma-shell"
  HYPRCHROMA_FIXTURE="$1" \
    XDG_CONFIG_HOME="$config" \
    XDG_STATE_HOME="$state" \
    HOME="$home" \
    PATH="$bin:$PATH" \
    "$lib/hyprchroma-terminals"
}

run_renderers "$tmp/palette.one"

test -f "$config/omarchy/runtime/starship.toml"
test -f "$config/omarchy/runtime/shell-theme.sh"
test -f "$config/omarchy/runtime/shell-theme.fish"
test -f "$config/omarchy/runtime/kitty.conf"
test -f "$config/omarchy/runtime/foot.ini"
test -f "$config/omarchy/runtime/ghostty.conf"
test -f "$state/hyprchroma/shell.json"
test -f "$state/hyprchroma/terminals.json"

grep -Fq 'palette = "hyprchroma"' "$config/omarchy/runtime/starship.toml"
grep -Fq 'format = "$directory"' "$config/omarchy/runtime/starship.toml"
grep -Fq 'export HYPRCHROMA_COLOR_ACCENT' "$config/omarchy/runtime/shell-theme.sh"
grep -Fq 'set -gx HYPRCHROMA_COLOR_ACCENT' "$config/omarchy/runtime/shell-theme.fish"
grep -Fq '"starship": "prompt-refresh"' "$state/hyprchroma/shell.json"
grep -Fq '"kitty": "new-windows-only"' "$state/hyprchroma/terminals.json"
sh -n "$config/omarchy/runtime/shell-theme.sh"
cmp -s "$config/alacritty.toml" <(printf '%s\n' '[general]' 'import = ["~/.config/alacritty/theme-active.toml"]')

first=$(sha256sum \
  "$config/omarchy/runtime/starship.toml" \
  "$config/omarchy/runtime/shell-theme.sh" \
  "$config/omarchy/runtime/kitty.conf" | sha256sum)
run_renderers "$tmp/palette.two"
second=$(sha256sum \
  "$config/omarchy/runtime/starship.toml" \
  "$config/omarchy/runtime/shell-theme.sh" \
  "$config/omarchy/runtime/kitty.conf" | sha256sum)
test "$first" != "$second"

echo "runtime target test passed"
