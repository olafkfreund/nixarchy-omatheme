---
status: draft
issue: 18
author: olafkfreund
---

# Intent: Desktop runtime target acceptance

## Problem

The theme engine documents runtime targets for GTK/libadwaita, Qt/KDE, GNOME
settings, Dark Reader, Pear, and Flatpak, but the executable test coverage is
currently concentrated on shells, terminals, Alacritty invariants, and the
Electron registry. This leaves the desktop target path without deterministic
proof that target enablement, disablement, status reporting, and palette
changes behave consistently for users with or without Stylix.

## Proposed outcome

The repository has a small, deterministic acceptance matrix for the existing
desktop runtime targets. It proves the targets can be enabled or disabled,
report their actual availability without claiming unsupported live reloads,
and preserve unrelated user files. A Razer smoke check reports which targets
are available on that host, while CI remains fixture-based and reproducible.

## Affected users and systems

- NixOS users who enable `programs.nixarchyThemeEngine`.
- Users whose theme source is Stylix or the runtime Omarchy engine.
- The hyprchroma runtime package, NixOS module, flake checks, and GitHub CI.
- The Razer host used for installed-application smoke verification.

## Constraints

- Do not edit `/home/olafkfreund/.config/nixos`.
- Do not add speculative application adapters in this task.
- Keep the engine functional when Stylix is absent.
- Do not mutate Flatpak permissions or install applications in tests.
- Preserve atomic runtime writes and explicit unavailable/unsupported status.
- Keep CI tests fixture-based; use Razer only for host-availability smoke checks.
- Existing shell, terminal, Electron, and Alacritty behavior must remain intact.

## Open questions

- Which desktop targets are installed and observable on Razer at test time?
- Which target statuses can be verified from existing scripts without adding a
  new status protocol?
