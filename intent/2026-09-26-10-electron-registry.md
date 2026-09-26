---
status: approved
issue: 10
author: olafkfreund
---

# Intent: Verified Electron application registry

## Problem

The runtime theme engine currently has one hard-coded Electron adapter for VS
Code. It has no common way to describe which Electron applications are
supported, whether they need a restart, or why an application must be left
unchanged. This makes the status shown to users incomplete and creates a risk
that an unverified application such as Discord could be mutated unsafely.

## Proposed outcome

The engine has an explicit Electron target registry. Each application reports a
clear runtime state such as synchronized, restart-required, unsupported, or
disabled. Verified applications can be synchronized through their documented
configuration boundary, while unsupported applications are detected and
reported without changing their files.

The Omarchroma panel exposes these states alongside the existing terminal
states, and theme switching continues to use one runtime synchronization path.

## Affected users and systems

- NixOS users enabling `programs.nixarchyThemeEngine`.
- Nixarchy users without Stylix.
- Stylix users using the runtime bridge.
- Electron applications installed on Razer and other Nixarchy hosts.
- The Hyprchroma renderer, NixOS/Home Manager module, and Omarchroma panel.

## Constraints

- Preserve the existing opt-in VS Code behavior and settings preservation.
- Do not mutate Discord or any other unverified Electron application.
- Keep Stylix and Home Manager as declarative template/configuration owners.
- Runtime writes must remain user-owned, atomic, and outside the Nix store.
- Unsupported or unavailable applications must produce an explicit status.
- No files may be created or edited in `/home/olafkfreund/.config/nixos`.
- Verify adapters on Razer without leaving a changed NixOS configuration.

## Open questions

- Which additional Electron application has a stable, documented configuration
  and reload contract suitable for the first registry entry after VS Code?
- Should restart-required adapters be enabled by default once verified, or stay
  opt-in like VS Code?
