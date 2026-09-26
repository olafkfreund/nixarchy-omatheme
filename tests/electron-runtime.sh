#!/usr/bin/env bash
set -euo pipefail

: "${HYPRCHROMA_PACKAGE:?HYPRCHROMA_PACKAGE must point to a built hyprchroma package}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

lib="$tmp/lib"
config="$tmp/config"
state="$tmp/state"
bin="$tmp/bin"
mkdir -p "$lib" "$config/Code/User" "$config/discord" "$config/Slack" "$config/obsidian" "$state" "$bin"

cp "$HYPRCHROMA_PACKAGE/lib/hyprchroma/hyprchroma-electron" "$lib/"
cp "$HYPRCHROMA_PACKAGE/lib/hyprchroma/hyprchroma-state" "$lib/"
bash_bin=$(command -v bash)
python_bin=$(command -v python3)
sed -i "1c#!$python_bin" "$lib/hyprchroma-electron" "$lib/hyprchroma-state"

cat > "$lib/hyprchroma-palette" <<'EOF'
#!/bin/sh
cat <<'PALETTE'
background	#101820
foreground	#f0f0e0
dark_background	#080c10
selection	#304050
accent	#40c0a0
muted	#809090
red	#e06060
green	#60c080
yellow	#d0b060
blue	#6090d0
magenta	#c080d0
PALETTE
EOF
chmod 755 "$lib/hyprchroma-palette"
sed -i "1c#!$bash_bin" "$lib/hyprchroma-palette"

cat > "$config/Code/User/settings.json" <<'EOF'
{
  "editor.fontSize": 17,
  "workbench.colorCustomizations": {
    "user.custom": "preserve",
    "editor.background": "#000000"
  }
}
EOF
cat > "$config/discord/settings.json" <<'EOF'
{"theme":"dark","userSetting":"preserve"}
EOF
cat > "$config/Slack/local-settings.json" <<'EOF'
{"useHwAcceleration":true,"userSetting":"preserve"}
EOF
cat > "$config/obsidian/obsidian.json" <<'EOF'
{"vaults":{"example":{"path":"/tmp/example"}},"userSetting":"preserve"}
EOF

run_electron() {
  XDG_CONFIG_HOME="$config" \
    XDG_STATE_HOME="$state" \
    HOME="$tmp/home" \
    PATH="$bin:$PATH" \
    "$lib/hyprchroma-electron" "$@"
}

run_electron status
for name in vscode discord slack obsidian; do
  grep -Fq "\"$name\":" "$state/hyprchroma/electron.json"
done
grep -Fq '"vscode": "supported"' "$state/hyprchroma/electron.json"
grep -Fq '"discord": "unsupported"' "$state/hyprchroma/electron.json"
grep -Fq '"slack": "unsupported"' "$state/hyprchroma/electron.json"
grep -Fq '"obsidian": "unsupported"' "$state/hyprchroma/electron.json"

run_electron vscode
grep -Fq '"editor.fontSize": 17' "$config/Code/User/settings.json"
grep -Fq '"user.custom": "preserve"' "$config/Code/User/settings.json"
grep -Fq '"editor.background": "#101820"' "$config/Code/User/settings.json"
grep -Fq '"vscode": "restart-required"' "$state/hyprchroma/electron.json"

discord_before=$(sha256sum "$config/discord/settings.json")
slack_before=$(sha256sum "$config/Slack/local-settings.json")
obsidian_before=$(sha256sum "$config/obsidian/obsidian.json")
run_electron discord
run_electron slack
run_electron obsidian
test "$discord_before" = "$(sha256sum "$config/discord/settings.json")"
test "$slack_before" = "$(sha256sum "$config/Slack/local-settings.json")"
test "$obsidian_before" = "$(sha256sum "$config/obsidian/obsidian.json")"

empty_config="$tmp/empty-config"
empty_state="$tmp/empty-state"
mkdir -p "$empty_config" "$empty_state"
XDG_CONFIG_HOME="$empty_config" XDG_STATE_HOME="$empty_state" "$lib/hyprchroma-electron" status
grep -Fq '"vscode": "unavailable"' "$empty_state/hyprchroma/electron.json"

linked_config="$tmp/linked-config"
mkdir -p "$linked_config/Code/User"
printf '%s\n' '{}' > "$tmp/store-settings.json"
ln -s "$tmp/store-settings.json" "$linked_config/Code/User/settings.json"
if XDG_CONFIG_HOME="$linked_config" XDG_STATE_HOME="$tmp/linked-state" "$lib/hyprchroma-electron" vscode; then
  echo "store-linked settings were not refused" >&2
  exit 1
fi
grep -Fq '"vscode": "refused"' "$tmp/linked-state/hyprchroma/electron.json"

echo "electron runtime test passed"
