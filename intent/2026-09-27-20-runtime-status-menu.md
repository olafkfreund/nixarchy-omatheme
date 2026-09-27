---
status: approved
issue: 20
author: olafkfreund
---

# Intent: Desktop runtime status in the Nixarchy menu

## Problem

Hyprchroma already records the outcomes of the desktop runtime targets in
`~/.local/state/hyprchroma/status.json`, including GTK, Qt/KDE, Dark Reader,
Pear Desktop, and Flatpak. The Omarchroma/Nixarchy plugin currently presents
shell, terminal, and Electron status, but does not expose this desktop status
to the user in the menu. Users therefore cannot quickly tell whether the
one-shot theme change synchronized a target, deferred it, disabled it, or found
the integration unavailable.

## Proposed outcome

The Nixarchy menu/plugin presents the current state of all desktop runtime
targets in one compact status row or section and updates when the existing
status file changes. Missing, malformed, or partial status data is represented
as unknown/unavailable rather than treated as synchronized. The feature uses
the existing status file and runtime engine; it does not introduce another
status protocol or require a rebuild for a theme switch.

## Affected users and systems

- NixOS and Nixarchy users running the Omarchroma menu plugin.
- The packaged QML plugin and its Nix build-time patching.
- Hyprchroma’s existing desktop status file and fixture checks.
- Stylix and no-Stylix installations, which must expose the same UI behavior.

## Constraints

- Reuse the existing `status.json` schema and QML `FileView`/`watchChanges`
  pattern used by shell, terminal, and Electron status.
- Keep status truthful: preserve synchronized, disabled, unavailable,
  deferred, restart-required, and unknown values where present.
- Do not add application adapters or change target synchronization semantics.
- Keep the menu compact and readable in the existing Nixarchy/Omarchy style.
- Handle missing, malformed, and partially populated files safely.
- Do not edit `/home/olafkfreund/.config/nixos`.
- Keep Stylix optional and preserve no-Stylix behavior.

## Open questions

- Should desktop status be one summary row or several target-specific rows?
- Which long status values need short display labels while retaining their raw
  values for truthful fallback behavior?
