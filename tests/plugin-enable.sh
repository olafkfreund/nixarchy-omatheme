#!/usr/bin/env bash
# nixarchyThemeEnginePlugin against a stub omarchy-shell (#45).
# PLUGIN_ENABLE is the unit's ExecStart; UNIT_SWITCH_METHOD and UNIT_TIMEOUT
# are the unit's X-SwitchMethod and TimeoutStartSec.
set -euo pipefail

fail=0
check() {
  if [ "$2" != "$3" ]; then
    echo "FAIL: $1: expected $3, got $2" >&2
    fail=1
  fi
}

check "unit X-SwitchMethod" "$UNIT_SWITCH_METHOD" keep-old
check "unit TimeoutStartSec" "$UNIT_TIMEOUT" 90

tmp=$(mktemp -d)
mkdir -p "$tmp/bin"
cat >"$tmp/bin/omarchy-shell" <<'EOF'
#!/usr/bin/env bash
echo "$* | timeout=${OMARCHY_SHELL_IPC_TIMEOUT:-unset}" >> "$STUB_LOG"
if [ "${2:-}" = enablePlugin ]; then
  calls=$(grep -c ' enablePlugin ' "$STUB_LOG")
  # A slow shell: the first two calls time out (no reply), the third answers.
  if [ "$STUB_MODE" = slow ] && [ "$calls" -ge 3 ]; then
    echo ok
  fi
fi
exit 0
EOF
chmod 755 "$tmp/bin/omarchy-shell"
sed -i "1c#!$(command -v bash)" "$tmp/bin/omarchy-shell"

run_case() {
  : >"$tmp/log"
  set +e
  STUB_MODE="$1" STUB_LOG="$tmp/log" PATH="$tmp/bin:$PATH" "$PLUGIN_ENABLE" 2>/dev/null
  rc=$?
  set -e
  rescans=$(grep -c ' rescanPlugins' "$tmp/log" || true)
  enables=$(grep -c ' enablePlugin ' "$tmp/log" || true)
  timeouts=$(grep -v -c 'timeout=15s$' "$tmp/log" || true)
}

run_case slow
check "slow shell: exit code" "$rc" 0
check "slow shell: rescanPlugins calls" "$rescans" 1
check "slow shell: enablePlugin calls" "$enables" 3
check "slow shell: calls without a 15s IPC timeout" "$timeouts" 0

run_case dead
check "dead shell: exit code" "$rc" 1
check "dead shell: rescanPlugins calls" "$rescans" 1
check "dead shell: enablePlugin calls" "$enables" 5

rm -rf "$tmp"
exit "$fail"
