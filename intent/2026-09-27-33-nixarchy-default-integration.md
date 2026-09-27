---
status: approved
issue: 33
author: olafkfreund
upstream-issue: https://github.com/olafkfreund/nixarchy/issues/1023
---

# Intent: Integrate omatheme into Nixarchy defaults

## Problem

Nixarchy's offline NixOS configuration does not currently include the
nixarchy-omatheme runtime engine. Users must add a separate input and module
themselves, even though Nixarchy already owns the Omarchy session, default
plugin registry, and NixOS/Home Manager integration point. Adding the plugin
without an ownership plan could install or enable the same Omarchroma files
twice.

## Proposed outcome

Nixarchy declaratively includes a pinned nixarchy-omatheme input and enables
its runtime theme engine for the Nixarchy `omarchy` user. The Omarchroma
plugin, daemon, hooks, and runtime bridges have one declarative owner, and a
fresh offline Nixarchy installation can switch themes with
`omarchy theme set <theme>` without another rebuild. Users who have Stylix
continue to use it as the declarative template; users without Stylix use the
same runtime path.

## Affected users and systems

- Nixarchy's upstream flake inputs and lock file.
- Nixarchy's NixOS/Home Manager module composition and default plugin set.
- Nixarchy offline ISO and fresh installed systems.
- Existing nixarchy-omatheme standalone NixOS users, whose module interface
  must remain compatible.
- Upstream plugin/module evaluation and runtime tests.

## Constraints

- Follow Nixarchy's pinned-input and default-plugin conventions.
- Do not duplicate ownership of the Omarchroma plugin directory or enablement
  state.
- Keep mutable runtime files outside the Nix store.
- Do not make Stylix a requirement.
- Preserve the `omarchy` user and Nixarchy's declarative rebuild workflow.
- Do not edit the user's machine configuration under `~/.config/nixos`.
- Validate with upstream flake checks and the existing nixarchy-omatheme checks.
- Keep the integration opt-outable where upstream's default-plugin policy
  requires it, subject to maintainer review.

## Open questions

- Should the upstream integration import the existing NixOS module directly,
  or should nixarchy-omatheme expose a dedicated Home Manager/default-plugin
  module so Nixarchy owns the plugin link while omatheme owns only the daemon
  and runtime hooks?
- Should the engine be enabled for every Nixarchy system by default, or gated
  behind a new `programs.nixarchy.themeEngine` option while still being part
  of the offline ISO?
- Which pinned commit should Nixarchy adopt after the integration contract is
  accepted?
