#!/usr/bin/env bash
# Runs upstream's Icons suites against the withIcons package. They expect an
# installed tree ($REPO with bin/, lib/, tests/, Panel.qml), so build one.
set -euo pipefail

: "${HYPRCHROMA_PACKAGE:?must point to the withIcons hyprchroma package}"
: "${PLUGIN_PANEL:?must point to the generated Panel.qml}"
: "${UPSTREAM_TESTS:?must point to upstream's tests directory}"
: "${PYTHON_ENV:?must point to the package's Python environment}"

repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT
mkdir -p "$repo/bin" "$repo/lib" "$repo/share" "$repo/tests"
cp "$HYPRCHROMA_PACKAGE/bin/hyprchroma" "$repo/bin/"
cp "$HYPRCHROMA_PACKAGE"/lib/hyprchroma/* "$repo/lib/"
cp -r "$HYPRCHROMA_PACKAGE"/share/hyprchroma/* "$repo/share/"
cp "$PLUGIN_PANEL" "$repo/Panel.qml"
cp "$UPSTREAM_TESTS/lib-omarchy.sh" "$UPSTREAM_TESTS/test-icons.sh" "$UPSTREAM_TESTS/test-icons-untrusted.sh" "$repo/tests/"
chmod u+w -R "$repo"

# Dropped: from "setup offers Reversal" to the next "# ---" header. Those cases
# run bin/hyprchroma-setup, which this package does not ship (it installs
# through Nix), and grep Panel.qml for the Arch install offer step 4 removed.
sed -i '/^# --- setup offers Reversal whenever Icons is included/,/^# ---/{/^# --- the sync asks/!d}' "$repo/tests/test-icons.sh"
# The suite's /usr/bin/python3 is the Python with Pillow here.
sed -i "s|/usr/bin/python3|$PYTHON_ENV/bin/python3|" "$repo/tests/test-icons-untrusted.sh"

# The sandbox has no Omarchy to resolve a palette, so the end-to-end cases read
# the seeded theme's colors.toml as the user palette file instead.
sed -i 's|^seed_omarchy_theme$|&; mkdir -p "$HOME/.config/hyprchroma"; cp "$HOME/.local/state/omarchy/current/theme/colors.toml" "$HOME/.config/hyprchroma/palette.toml"|' "$repo/tests/test-icons.sh"

export PATH="$PYTHON_ENV/bin:$PATH"
fail=0
for suite in test-icons.sh test-icons-untrusted.sh; do
  out=$(bash "$repo/tests/$suite" 2>&1) || { echo "$suite exited nonzero" >&2; fail=1; }
  printf '%s\n' "$out"
  if grep -q 'FAIL' <<<"$out"; then fail=1; fi
done
exit $fail
