---
status: approved
issue: 12
author: olafkfreund
---

# Intent: Shell and CLI runtime theme targets

## Problem

The runtime theme engine currently synchronizes desktop applications, terminal
emulators, and selected Electron applications, but shell UX remains outside the
runtime boundary. Starship, Bash, Zsh, Fish, and small terminal applications
such as fzf, bat, btop, yazi, and tmux can continue showing the previous colors
after an Omarchy theme switch. Their configuration ownership and reload
semantics also differ, so treating them as ordinary desktop targets would risk
overwriting user configuration or claiming a live update that did not occur.

## Proposed outcome

Shell and CLI integrations have an explicit target family with clear ownership
and status. A theme switch updates the verified runtime palette for the shell
environment and prompt, reports whether existing sessions refreshed or only new
processes are affected, and leaves unsupported applications unchanged.

The first verified wave covers Starship plus Bash, Zsh, and Fish shell startup
and prompt behavior. Additional CLI applications are evaluated individually
and added only when their configuration boundary and reload behavior are safe
and demonstrable.

## Affected users and systems

- NixOS users enabling `programs.nixarchyThemeEngine`.
- Nixarchy users without Stylix.
- Stylix users using the runtime bridge.
- Interactive Bash, Zsh, and Fish sessions.
- Starship and selected CLI tools running inside Omarchy terminals.
- The Hyprchroma renderer, NixOS/Home Manager module, and Omarchroma panel.

## Constraints

- Stylix and Home Manager retain declarative ownership of stable shell
  structure, aliases, modules, and user preferences.
- Runtime color data must be user-owned, atomic, and outside the Nix store.
- Existing shell configuration must not be replaced wholesale.
- Existing sessions must not be claimed as live-updated unless verified.
- Unsupported CLI applications must be reported or ignored, never mutated
  speculatively.
- No files may be created or edited in `/home/olafkfreund/.config/nixos`.
- Verify the integrations on Razer and restore its original generation after
  testing.

## Open questions

- Which runtime status vocabulary best distinguishes prompt refresh, new-shell
  only, restart-required, unavailable, and unsupported?
- Which of btop, fzf, bat, yazi, and tmux have safe first-wave boundaries after
  Starship and the three shells are verified?
