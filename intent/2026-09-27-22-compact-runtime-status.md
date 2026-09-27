---
status: draft
issue: 22
author: olafkfreund
---

# Intent: Compact runtime status on narrow bars

## Problem

The Nixarchy plugin now shows shell, terminal, Electron, and desktop runtime
states as long text rows. On narrow bars these rows are truncated, making it
hard to distinguish important states such as synced, unavailable, disabled,
deferred, restart-required, and unknown. The status data itself is correct;
the presentation is not consistently readable.

## Proposed outcome

The plugin presents runtime health in a compact layout that remains legible at
narrow representative widths and still works at wide widths. All current
status groups remain represented, state distinctions remain truthful, and the
existing live file-watching behavior continues to update the display.

## Affected users and systems

- NixOS and Nixarchy users with narrow or wide Omarchy bars.
- The packaged Omarchroma/Nixarchy QML plugin.
- Existing shell, terminal, Electron, and desktop status models.
- Plugin build-time marker checks and CI.

## Constraints

- Reuse the current QML status properties and label mappings.
- Do not change Hyprchroma’s status JSON or synchronization semantics.
- Preserve the existing Nixarchy/Omarchy visual language and safe elision.
- Keep missing and malformed status handling unchanged.
- Do not edit `/home/olafkfreund/.config/nixos`.
- Do not add a UI framework or speculative responsive abstraction.

## Open questions

- Should compact mode use grouped summary labels, shorter target labels, or a
  small number of stacked rows selected by available width?
- What representative narrow width should the build-time/layout check cover?
