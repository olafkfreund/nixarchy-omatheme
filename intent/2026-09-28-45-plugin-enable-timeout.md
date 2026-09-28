---
status: approved
issue: 45
author: olafkfreund
---

# Intent: enabling the Omarchroma plugin can't stall a deploy or churn the shell

## Problem

`nixarchyThemeEnginePlugin.service` (`modules/nixos.nix`: `pluginEnableScript`
and the user service around line 460) enables
`io.github.nobledoodle.omarchroma` in the Omarchy shell. It is a `oneshot`
started from Home Manager activation, and on a busy shell it goes wrong in
three ways that feed each other:

1. **The IPC timeout is too short.** `omarchy-shell` gives each call 2 s.
   Right after a switch, a plugin-heavy shell answers `enablePlugin` more
   slowly than that, so the call returns empty and the script counts it as a
   failure. Run by hand with `OMARCHY_SHELL_IPC_TIMEOUT=20s`, the same call
   returns `ok` first time.
2. **Every retry rescans.** Each of up to 30 attempts runs
   `rescanPlugins`, which makes the live shell reload its plugins. The bars
   flicker or blank, and the shell gets slower, so the next call times out
   too.
3. **Nothing bounds it.** The unit has no start timeout
   (`TimeoutStartUSec=infinity`). Home Manager's activation waits on it,
   hits its own 5-minute limit, and `switch-to-configuration` exits 4.

On p620 (2026-09-28) the unit was still `activating` 6 minutes into a
switch. Stopping it unblocked the deploy, and the plugin turned out to be
loaded already. On razer the same unit failed after ~40 s instead.

## Proposed outcome

- After a switch, the plugin ends up enabled without the unit ever holding
  Home Manager's activation for more than a short, bounded time.
- The live shell is rescanned at most once per run, not once per retry.
- A plugin that is already enabled counts as success immediately.
- If the shell really is unavailable, the unit gives up quickly and says so,
  and a later login or theme switch enables the plugin.

## Affected users and systems

- `modules/nixos.nix` (the script and the unit), plus a test if the repo's
  checks can cover the script's control flow with a stub `omarchy-shell`.
- Downstream: nixarchy's pin, then nixos_config. The hosts are p620 and razer.
- Until it ships, an HM activation that hangs on p620 can be unblocked with
  `systemctl --user stop nixarchyThemeEnginePlugin`.

## Constraints

- It must still enable the plugin on a fresh install, where the shell may
  start after the unit.
- It must not delay the user's login noticeably.
- The fix belongs in this repo. omarchy-shell's 2 s default is upstream
  behaviour, and this unit is the caller that needs longer.

## Open questions

1. **Should the unit run from Home Manager activation at all**, or only at
   graphical-session start? Activation is what couples it to deploys. I
   recommend login only, plus a single, bounded, non-blocking attempt at
   activation.
2. **What timeouts?** I propose `OMARCHY_SHELL_IPC_TIMEOUT=15s` per call, at
   most 5 attempts with a growing back-off, and `TimeoutStartSec=90` on the
   unit.
