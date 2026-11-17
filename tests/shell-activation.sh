#!/usr/bin/env bash
set -euo pipefail

: "${SHELL_ACTIVATION:?}"
: "${BASH_HOOK_OFF:?}" "${BASH_HOOK_ON:?}" "${ZSH_HOOK_OFF:?}" "${ZSH_HOOK_ON:?}"
: "${FISH_HOOK_OFF:?}" "${FISH_HOOK_ON:?}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Home Manager's own run helper.
run() { if [[ -v DRY_RUN ]]; then echo "$@"; else "$@"; fi; }
export -f run

fail() { echo "FAIL: $*" >&2; exit 1; }

# A fresh HOME per case; sets $home, $log, $err.
fresh_home() {
  home=$(mktemp -d -p "$tmp")
  log="$home/stub.log"
  err="$home/stderr"
  mkdir -p "$home/.config"
  : > "$log"
}
# Run the generated shell entry under Home Manager's set -eu.
run_entry() {
  HOME="$home" STUB_LOG="$log" \
    STUB_BASE="$home/.config/omarchy/runtime/starship.base.toml" \
    bash -eu "$SHELL_ACTIVATION" 2> "$err" || fail "entry exited $?"
}

# 1. A symlinked config is copied by content; the base exists when the renderer runs.
fresh_home
printf 'format = "$time"\n' > "$home/real.toml"
ln -s "$home/real.toml" "$home/.config/starship.toml"
run_entry
runtime="$home/.config/omarchy/runtime"
grep -Fxq 'format = "$time"' "$runtime/starship.base.toml" || fail "base content"
test ! -L "$runtime/starship.base.toml" || fail "base is a link"
test "$(cat "$log")" = "$(printf 'palette\nhyprchroma shell base=present')" || fail "log: $(cat "$log")"

# 2. A missing source and a dangling link both remove the base and still render.
for kind in missing dangling; do
  fresh_home
  runtime="$home/.config/omarchy/runtime"
  mkdir -p "$runtime"
  echo old > "$runtime/starship.base.toml"
  if [ "$kind" = dangling ]; then ln -s "$home/nowhere" "$home/.config/starship.toml"; fi
  run_entry
  test ! -e "$runtime/starship.base.toml" || fail "$kind: base kept"
  grep -Fq 'hyprchroma shell' "$log" || fail "$kind: no render"
done

# 3. No palette: no render, no status file.
fresh_home
printf 'a = 1\n' > "$home/.config/starship.toml"
STUB_PALETTE_RC=1 run_entry
if grep -Fq 'hyprchroma shell' "$log"; then fail "rendered without a palette"; fi
test ! -e "$home/.local/state/hyprchroma/shell.json" || fail "status written"

# 4. A failed render warns and the switch still succeeds.
fresh_home
STUB_RENDER_RC=1 run_entry
grep -Fq 'prompt render failed' "$err" || fail "no warning: $(cat "$err")"

# 5. Dry run writes and renders nothing.
fresh_home
printf 'a = 1\n' > "$home/.config/starship.toml"
DRY_RUN=1 run_entry
test ! -e "$home/.config/omarchy/runtime/starship.base.toml" || fail "dry run wrote the base"
test ! -s "$log" || fail "dry run ran the stubs: $(cat "$log")"

# Hooks: with targets.starship = false the shell keeps its own STARSHIP_CONFIG.
hook_home=$(mktemp -d -p "$tmp")
mkdir -p "$hook_home/.config/omarchy/runtime"
echo 'export STARSHIP_CONFIG=/runtime' > "$hook_home/.config/omarchy/runtime/shell-theme.sh"
echo 'set -gx STARSHIP_CONFIG /runtime' > "$hook_home/.config/omarchy/runtime/shell-theme.fish"

# Each call is a fresh process: the hook caches the theme file's mtime.
hook_value() { # shell hook-file preset
  local shell=$1 hook=$2 preset=$3
  local sh_prog='source "$1"; _hyprchroma_shell_refresh; echo "${STARSHIP_CONFIG-UNSET}"'
  local fish_prog='source $argv[1]; emit fish_prompt; if set -q STARSHIP_CONFIG; echo $STARSHIP_CONFIG; else; echo UNSET; end'
  local args
  case $shell in
    bash) args=(--norc -c "$sh_prog" _ "$hook") ;;
    zsh) args=(-f -c "$sh_prog" _ "$hook") ;;
    fish) args=(--no-config -c "$fish_prog" "$hook") ;;
  esac
  if [ -n "$preset" ]; then
    HOME="$hook_home" STARSHIP_CONFIG="$preset" "$shell" "${args[@]}"
  else
    env -u STARSHIP_CONFIG HOME="$hook_home" "$shell" "${args[@]}"
  fi
}
expect() { [ "$1" = "$2" ] || fail "$3: got '$1', want '$2'"; }

for shell in bash zsh fish; do
  upper=${shell^^}
  off=${upper}_HOOK_OFF
  on=${upper}_HOOK_ON
  expect "$(hook_value "$shell" "${!off}" /mine)" /mine "$shell off with preset"
  expect "$(hook_value "$shell" "${!off}" '')" UNSET "$shell off unset"
  expect "$(hook_value "$shell" "${!on}" /mine)" /runtime "$shell on"
done

echo "shell activation test passed"
