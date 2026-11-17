#!/usr/bin/env bash
set -euo pipefail

: "${HYPRCHROMA_PACKAGE:?HYPRCHROMA_PACKAGE must point to a built hyprchroma package}"
lib="$HYPRCHROMA_PACKAGE/lib/hyprchroma"
bin="$HYPRCHROMA_PACKAGE/bin/hyprchroma"

# The Icons sync lane has room for a first apply on a slower host (#66, D6).
grep -qx 'ICONS_SECONDS=180' "$bin" || { echo "ICONS_SECONDS is not 180" >&2; exit 1; }

# a. -wrapped names normalise to the real program name (readlink is mocked).
LIB="$lib" python3 -I - <<'PY'
import os, sys

def load(name):
    src = open(os.path.join(os.environ["LIB"], name)).read().split('\nif __name__ == "__main__":')[0]
    ns = {"__name__": name}
    exec(compile(src, name, "exec"), ns)
    return ns

def check(fn, cases):
    for link, want in cases:
        os.readlink = lambda path, link=link: link
        got = fn("1")
        assert got == want, f"{link!r}: got {got!r}, want {want!r}"

check(load("hyprchroma-state")["window_executable"], [
    ("/nix/store/x/bin/.kitty-wrapped", "kitty"),
    ("/nix/store/x/bin/.kitty-wrapped (deleted)", "kitty"),
    ("/nix/store/x/bin/foot", "foot"),
])
# running_executables feeds the stale-app exclusion of re-themed terminals.
state = load("hyprchroma-state")
os.readlink = lambda path: "/nix/store/x/bin/.kitty-wrapped (deleted)"
names = state["running_executables"]()
assert "kitty" in names and ".kitty-wrapped" not in names, f"running_executables: {sorted(names)[:5]}"
check(load("hyprchroma-dark-reader")["running_executable"], [
    ("/nix/store/x/bin/.chromium-wrapped", "chromium"),
    ("/nix/store/x/bin/.chromium-wrapped (deleted)", "chromium"),
    ("/nix/store/x/bin/chromium", "chromium"),
])
PY

# b. The default build ships the real Icons helper without Pillow: status and revert
# work, and an apply that has an app icon to draw stops with the helper's own message.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home/.local/share/applications" "$tmp/share/icons/Reversal/places/scalable" \
  "$tmp/share/icons/Reversal-dark" "$tmp/share/icons/hicolor/48x48/apps"
printf '[Icon Theme]\nName=Reversal\n' > "$tmp/share/icons/Reversal/index.theme"
cp "$tmp/share/icons/Reversal/index.theme" "$tmp/share/icons/Reversal-dark/index.theme"
printf '<svg><path fill="#f5aa1e"/></svg>' > "$tmp/share/icons/Reversal/places/scalable/folder.svg"
printf '[Desktop Entry]\nName=x\nIcon=x\nExec=true\n' > "$tmp/home/.local/share/applications/x.desktop"
printf '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48"><rect width="48" height="48"/></svg>' \
  > "$tmp/share/icons/hicolor/48x48/apps/x.svg"
icons() {
  env -i HOME="$tmp/home" XDG_DATA_DIRS="$tmp/share" HYPRCHROMA_ICONS_ISOLATED=1 \
    "$lib/hyprchroma-icons" "$@"
}
out=$(icons status 2>&1) || { echo "icons status failed: $out" >&2; exit 1; }
printf '%s' "$out" | python3 -I -c 'import json, sys; assert json.load(sys.stdin)["theme"] == "Omarchroma-Icons"' ||
  { echo "icons status is not JSON: $out" >&2; exit 1; }
rc=0
out=$(icons apply 2>&1) || rc=$?
[[ $rc -ne 0 && $out == *"python-pillow is not installed"* ]] || { echo "icons apply exited $rc: $out" >&2; exit 1; }
icons revert >/dev/null 2>&1 || { echo "icons revert failed" >&2; exit 1; }

# c. Profile lookups must survive an unset USER (set -u).
for f in sync-gtk-theme sync-qt-kde-theme; do
  grep -qF '${USER:-}' "$lib/$f"
  if grep -E '\$USER([^A-Za-z_]|$)|\$\{USER\}' "$lib/$f"; then
    echo "$f has a bare USER reference" >&2
    exit 1
  fi
done

# d. framework_apps forces its Thunderbird and Pear calls.
for app in thunderbird pear; do
  for state in true false; do
    grep -qF -- "--target=$app --set-enabled=$state --quiet --force" "$bin"
  done
done

# e. A recorded off browsers/thunderbird exits early: running their revert at every
# service start marked a theme change and listed every window as stale.
grep -qF 'elif [[ $target != dark-reader && $target != qt-kde ]]; then' "$bin"

# f. Icons stays off even when settings record it on (an earlier Arch install).
grep -qF '[[ $key == icons ]] && return 1' "$bin"
