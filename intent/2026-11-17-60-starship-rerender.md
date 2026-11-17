---
status: draft
issue: 60
author: olafkfreund
---

# Intent: A Home Manager starship change reaches the prompt at the next switch

## Problem

Every interactive shell reads its prompt from
`~/.config/omarchy/runtime/starship.toml` (`STARSHIP_CONFIG`, set by
`runtime/shell-theme.sh`). That file is rendered by `hyprchroma shell`
(`pkgs/hyprchroma-shell`) from `runtime/starship.base.toml` plus the active
theme's palette.

Two steps feed it, and nothing orders them:

- `home.activation.nixarchyThemeEngineShell` (`modules/nixos.nix:402-418`)
  copies the Home Manager `~/.config/starship.toml` to `starship.base.toml`.
  It runs after `linkGeneration`.
- `hyprchroma shell` runs only in `hyprchromad.service`'s `ExecStartPre`
  (`modules/nixos.nix:498-500`), that is at login or when the unit is
  restarted, and at a theme change.

So a change made through `programs.starship.settings` and applied with a
switch does not show in a new terminal. It shows only after the next login
or theme change. The reporter's runtime file held a config weeks old while
the base was current.

Evidence from p620, switch at 2026-11-17 06:46:
`hyprchroma-shell: shell colors synchronized` at 06:46:24 (the unit was
restarted during the switch), then `starship.base.toml` was written at
06:46:25. The render ran one second before the new base existed. That switch
did not change the starship settings, so the files agree today, but a switch
that does change them leaves the old prompt.

## Proposed outcome

After a switch that changes `programs.starship.settings` (or a hand-written
`~/.config/starship.toml`), a new terminal shows the new prompt, in the active
theme's colours, without logging out or changing the theme. A switch that
does not change the starship config leaves the runtime file as it is.

## Affected users and systems

- `modules/nixos.nix` (the shell activation entry, and possibly the
  `hyprchromad` unit), and its tests under `tests/`.
- Every Nixarchy user with the shell target on. On the owner's fleet: p620,
  razer, p510.

## Constraints

- Must respect Home Manager's `DRY_RUN` (use `run`).
- Must not fail the switch when no graphical session or no palette exists
  (first activation, headless host, CI VM).
- Must not change the rendered output itself: same palette block, same
  `hyprchroma shell` code path the daemon uses.
- Must not leave the shell target off for users who turned it off
  (`shellTargetsEnabled`).
- Must not rely on the activation entry running before or after the unit
  restart by chance.

## Open questions

1. Where should the re-render live: at the end of `nixarchyThemeEngineShell`
   (the issue's suggestion and the reporter's working workaround), or in
   `hyprchromad` by watching `starship.base.toml`? My lean is the activation
   entry: one line, the same command, no new watcher.
2. Should the render also run when no graphical session is active (it only
   needs the palette and writes files), or only when `hyprchromad` is
   running?
