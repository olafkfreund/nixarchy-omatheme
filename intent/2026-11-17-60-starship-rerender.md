---
status: approved
issue: 60
author: olafkfreund
---

# Intent: A Home Manager starship change reaches the prompt at the next switch

## Problem

Shells with a Nixarchy shell target on (`targets.bash`, `targets.zsh`,
`targets.fish`) read their prompt from
`~/.config/omarchy/runtime/starship.toml`, through `STARSHIP_CONFIG` in
`runtime/shell-theme.sh` (Bash, Zsh) or `runtime/shell-theme.fish` (Fish).
`hyprchroma shell` (`pkgs/hyprchroma-shell`) renders that file from
`runtime/starship.base.toml` plus the active theme's palette.

`home.activation.nixarchyThemeEngineShell` (`modules/nixos.nix:402-419`)
copies the Home Manager `~/.config/starship.toml` to `starship.base.toml` at
every switch. Nothing makes a render follow that copy:

1. **No trigger.** The renderer runs when `hyprchromad.service` starts
   (`ExecStartPre`, `modules/nixos.nix:498-500`) and inside a full sync
   (`pkgs/hyprchroma.nix:133-142`): a theme, font or framework change, or
   `hyprchroma --force`. A switch that changes only the starship settings
   leaves the unit's definition as it was, so Home Manager does not restart
   it, and the sync's fingerprint leaves out `starship.base.toml` (upstream
   `bin/hyprchroma:970-981`, `1075-1079`), so a sync skips it as unchanged.
   This is why the reporter's runtime file was weeks behind a current base.
2. **No order.** When a switch does restart the unit (for another reason),
   nothing orders the render against the copy. On p620, at the
   2026-11-17 06:46 switch, the journal shows
   `hyprchroma-shell: shell colors synchronized` at 06:46:24 and
   `starship.base.toml` was written at 06:46:25: the render read the old
   base. That switch did not change the starship settings, so no stale
   prompt resulted that time.

So a change made through `programs.starship.settings` (or to a hand-written
`~/.config/starship.toml`) and applied with a switch shows only after the
next login or theme change.

## Proposed outcome

- After a switch that changes the starship config, the next prompt in a new
  or open terminal uses the new config, in the active theme's colours,
  without logging out or changing the theme.
- When no palette exists yet (first activation, headless host, CI VM), the
  switch still succeeds and nothing is written; the prompt is rendered once
  a palette exists, as today.
- When neither the starship config nor the palette changed, the rendered
  prompt's content is unchanged. A runtime file that is stale or missing is
  repaired at the next switch.

## Affected users and systems

- The shell activation in `modules/nixos.nix`, possibly the `hyprchromad`
  unit and the renderer, and their tests under `tests/`.
- Nixarchy users with a shell target on. On the owner's fleet: p620, razer,
  p510.

## Constraints

- Must honour Home Manager's dry run.
- Must keep the renderer's output contract: same palette block, same theme
  mode handling as the daemon's render (`NIXARCHY_THEME_ENGINE_MODE`).
- Shell targets the user turned off stay off: nothing rendered for them.
- Must not depend on the order of the activation entry and the unit restart
  by chance.
- Must find a starship installed only through Home Manager
  (`/etc/profiles/per-user/$USER/bin`). The renderer's trusted path
  (`pkgs/hyprchroma.nix:24-25`) has `/run/current-system/sw/bin` but no
  per-user profile, and without starship the renderer skips the prompt
  silently. p620 has starship in both, so the gap does not show there.
- p510: no build or deploy without the owner's OK.

## Decisions (owner, 2026-11-17)

1. Removing `~/.config/starship.toml` is in scope: the prompt falls back to
   the default at the next switch.
2. Hand edits without a switch are out of scope.
