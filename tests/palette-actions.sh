#!/usr/bin/env bash
set -euo pipefail

: "${PLUGIN_PANEL:?PLUGIN_PANEL must point to the generated Panel.qml}"
: "${TMPDIR:?TMPDIR must be set}"

grep -F '"palette", "--capture"' "$PLUGIN_PANEL" >/dev/null
grep -F '"restore", "--captured"' "$PLUGIN_PANEL" >/dev/null
grep -F '"restore", "--stock"' "$PLUGIN_PANEL" >/dev/null
grep -F 'startDaemonProcess' "$PLUGIN_PANEL" >/dev/null
for forbidden in hyprchroma-setup hyprchroma-uninstall '"icons"' 'toggleFramework("icons")' \
  iconsStatusProcess iconsView openUninstall installDependency; do
  if grep -F -- "$forbidden" "$PLUGIN_PANEL"; then
    echo "Panel.qml still contains $forbidden" >&2
    exit 1
  fi
done

stub="$TMPDIR/hyprchroma"
log="$TMPDIR/hyprchroma-arguments"
cat > "$stub" <<'EOF'
printf '%s\n' "$*" >> "$HYPRCHROMA_ACTION_LOG"
EOF
bash_bin=$(command -v bash)

HYPRCHROMA_ACTION_LOG="$log" "$bash_bin" "$stub" palette --capture
HYPRCHROMA_ACTION_LOG="$log" "$bash_bin" "$stub" restore --captured
HYPRCHROMA_ACTION_LOG="$log" "$bash_bin" "$stub" restore --stock

test "$(wc -l < "$log")" -eq 3
grep -Fx 'palette --capture' "$log" >/dev/null
grep -Fx 'restore --captured' "$log" >/dev/null
grep -Fx 'restore --stock' "$log" >/dev/null
