#!/usr/bin/env bash
set -euo pipefail

: "${HYPRCHROMA_PACKAGE:?HYPRCHROMA_PACKAGE must point to a built hyprchroma package}"
lib="$HYPRCHROMA_PACKAGE/lib/hyprchroma"
bin="$HYPRCHROMA_PACKAGE/bin/hyprchroma"

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
check(load("hyprchroma-dark-reader")["running_executable"], [
    ("/nix/store/x/bin/.chromium-wrapped", "chromium"),
    ("/nix/store/x/bin/.chromium-wrapped (deleted)", "chromium"),
    ("/nix/store/x/bin/chromium", "chromium"),
])
PY

# b. The icons stub: status/revert are silent no-ops, everything else is refused.
for word in status revert; do
  out=$("$lib/hyprchroma-icons" "$word" 2>&1)
  [[ -z $out ]] || { echo "icons $word printed: $out" >&2; exit 1; }
done
for word in apply folders set covers bogus; do
  rc=0
  out=$("$lib/hyprchroma-icons" "$word" 2>&1 >/dev/null) || rc=$?
  [[ $rc -eq 1 ]] || { echo "icons $word exited $rc" >&2; exit 1; }
  [[ $out == *"Icons is not available on NixOS (#66)"* ]] || { echo "icons $word: $out" >&2; exit 1; }
done

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

# e. Thunderbird skips the fast path like browsers.
grep -qF '$target != browsers && $target != thunderbird' "$bin"
