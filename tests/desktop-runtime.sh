#!/usr/bin/env bash
set -euo pipefail

: "${HYPRCHROMA_PACKAGE:?HYPRCHROMA_PACKAGE must point to a built hyprchroma package}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

prefix="$tmp/prefix"
config="$tmp/config"
data="$tmp/data"
state="$tmp/state"
runtime="$tmp/runtime"
home="$tmp/home"
bin="$tmp/bin"
mkdir -p "$prefix" "$config" "$data" "$state" "$runtime" "$home" "$bin"
mkdir -p "$tmp/flatpak"
mkdir -p "$tmp/theme"
chmod 700 "$runtime" "$home"

cat > "$bin/hyprctl" <<'EOF'
#!/bin/sh
printf '%s\n' '[]'
EOF
cat > "$bin/xdg-settings" <<'EOF'
#!/bin/sh
printf '%s\n' browseros.desktop
EOF
cat > "$bin/omarchy" <<EOF
#!/bin/sh
case "\${1:-} \${2:-}" in
  "theme current") printf '%s\\n' fixture ;;
  "theme dir") printf '%s\\n' "$tmp/theme" ;;
  "font current") printf '%s\\n' Noto-Sans ;;
  *) exit 0 ;;
esac
EOF
printf '%s\n' NixarchyMissingIcon > "$tmp/theme/icons.theme"
chmod 755 "$bin/hyprctl" "$bin/xdg-settings" "$bin/omarchy"

cp -a "$HYPRCHROMA_PACKAGE/bin" "$prefix/"
cp -a "$HYPRCHROMA_PACKAGE/lib" "$prefix/"
cp -a "$HYPRCHROMA_PACKAGE/share" "$prefix/"
chmod -R u+w "$prefix"

bash_bin=$(command -v bash)
python_bin=$(command -v python3)
util_bin=$(dirname "$(readlink -f "$(command -v flock)")")
glib_bin=$(dirname "$(readlink -f "$(command -v gsettings)")")
awk_bin=$(dirname "$(readlink -f "$(command -v awk)")")
for file in "$prefix"/bin/* "$prefix"/lib/hyprchroma/*; do
  case "$(head -n 1 "$file")" in
    '#!/usr/bin/env bash') sed -i "1c#!$bash_bin" "$file" ;;
    '#!/usr/bin/env python3') sed -i "1c#!$python_bin" "$file" ;;
  esac
done
for file in \
  "$prefix/bin/hyprchroma" \
  "$prefix/lib/hyprchroma/sync-gtk-theme" \
  "$prefix/lib/hyprchroma/sync-qt-kde-theme"; do
  sed -i "s#for directory in #for directory in $bin $util_bin $glib_bin $awk_bin #" "$file"
done
for file in "$prefix"/bin/* "$prefix"/lib/hyprchroma/*; do
  sed -i "s#PATH_CANDIDATES = (#PATH_CANDIDATES = (\"$bin\", \"$util_bin\", \"$glib_bin\", \"$awk_bin\", #" "$file"
done
sed -i "s#\[\"hyprctl\",#[\"$bin/hyprctl\",#g" \
  "$prefix/lib/hyprchroma/hyprchroma-state"
sed -i "s#\[\"xdg-settings\",#[\"$bin/xdg-settings\",#g" \
  "$prefix/lib/hyprchroma/hyprchroma-dark-reader"

cat > "$tmp/palette.one" <<'EOF'
background	#101820
dark_background	#0c1218
darker_background	#080c10
lighter_background	#304050
foreground	#f0f0e0
dark_foreground	#809090
light_foreground	#c0c0b0
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
mode	dark
EOF

cat > "$tmp/palette.two" <<'EOF'
background	#201018
dark_background	#180c12
darker_background	#10080c
lighter_background	#503040
foreground	#f8e8f0
dark_foreground	#a090a0
light_foreground	#d0b8c8
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
mode	light
EOF

cat > "$prefix/lib/hyprchroma/hyprchroma-palette" <<'EOF'
#!/bin/sh
set -eu
case "${1:-}" in
  --source) printf '%s\n' fixture ;;
  --all|--for-sync) cat "$HYPRCHROMA_FIXTURE" ;;
  *)
    found=false
    while IFS="$(printf '\t')" read -r key value; do
      if [ "$key" = "${1:-}" ]; then
        printf '%s\n' "$value"
        found=true
        break
      fi
    done < "$HYPRCHROMA_FIXTURE"
    [ "$found" = true ]
    ;;
esac
EOF
chmod 755 "$prefix/lib/hyprchroma/hyprchroma-palette"

run_target() {
  local toggle="${3:-}"
  local -a arguments=("--target=$2")
  [[ -z "$toggle" ]] || arguments+=("$toggle")
  HYPRCHROMA_FIXTURE="$1" \
    HOME="$home" \
    XDG_CONFIG_HOME="$config" \
    XDG_DATA_HOME="$data" \
    XDG_STATE_HOME="$state" \
    XDG_RUNTIME_DIR="$runtime" \
    FLATPAK_USER_DIR="$tmp/flatpak" \
    "$prefix/bin/hyprchroma" "${arguments[@]}" --quiet
}

run_target "$tmp/palette.one" gtk --set-enabled=true
run_target "$tmp/palette.one" qt-kde --set-enabled=true
run_target "$tmp/palette.one" dark-reader --set-enabled=true
run_target "$tmp/palette.one" pear --set-enabled=true
run_target "$tmp/palette.one" flatpak --set-enabled=true

test -f "$home/.config/gtk-3.0/gtk.css"
test -f "$home/.config/gtk-4.0/gtk.css"
test -f "$data/color-schemes/Hyprchroma.colors"
test -f "$config/kdeglobals"
test -f "$data/hyprchroma/dark-reader-theme.json"
test "$(jq -r '.gtk' "$state/hyprchroma/status.json")" = synchronized
test "$(jq -r '.qtKde' "$state/hyprchroma/status.json")" = synchronized
test "$(jq -r '.pearDesktop' "$state/hyprchroma/status.json")" = not-installed
case "$(jq -r '.flatpak' "$state/hyprchroma/status.json")" in
  not-installed|synchronized) ;;
  *) exit 1 ;;
esac

marker="$config/unrelated.txt"
printf '%s\n' keep-me > "$marker"
first=$(sha256sum \
  "$home/.config/gtk-3.0/gtk.css" \
  "$config/kdeglobals" \
  "$data/color-schemes/Hyprchroma.colors" \
  "$data/hyprchroma/dark-reader-theme.json" | sha256sum)
run_target "$tmp/palette.two" gtk --set-enabled=true
run_target "$tmp/palette.two" qt-kde --set-enabled=true
run_target "$tmp/palette.two" dark-reader --set-enabled=true
second=$(sha256sum \
  "$home/.config/gtk-3.0/gtk.css" \
  "$config/kdeglobals" \
  "$data/color-schemes/Hyprchroma.colors" \
  "$data/hyprchroma/dark-reader-theme.json" | sha256sum)
test "$first" != "$second"
grep -Fq '#e080c0' "$home/.config/gtk-3.0/hyprchroma.css"
test "$(cat "$marker")" = keep-me

run_target "$tmp/palette.two" gtk --set-enabled=false
test ! -f "$home/.config/gtk-3.0/gtk.css"
test "$(cat "$marker")" = keep-me

echo "desktop runtime test passed"
