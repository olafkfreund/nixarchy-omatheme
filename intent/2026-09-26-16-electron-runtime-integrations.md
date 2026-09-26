---
status: approved
issue: 16
author: olafkfreund
---

# Intent: Expand verified Electron runtime integrations

## Problem

The runtime theme engine currently has a verified VS Code Electron adapter and
reports Discord as unsupported. Electron applications do not share one safe
configuration or reload contract, so broad theme mutation can damage settings,
trigger crashes, or silently claim success when the application did not reload.

## Proposed outcome

The Electron registry supports additional applications only after their config
ownership, generated-entry boundary, and reload behavior are verified. Supported
applications update at runtime without damaging user settings; unsupported or
unsafe applications remain explicitly inert and visible as unsupported. Each
adapter has isolated tests and clear status reporting.

## Affected users and systems

- NixOS and Nixarchy users running Electron applications.
- Hyprchroma's Electron registry and runtime adapters.
- The Omarchroma menu plugin and status files.
- Stylix users and users running without Stylix.
- Razer as the acceptance-testing host, including prior Discord crash history.

## Constraints

- Do not edit `/home/olafkfreund/.config/nixos`.
- Never rewrite an application's complete settings file; mutate only an owned,
  marked generated section.
- Unsupported applications must remain inert rather than receiving a guessed
  adapter.
- Do not launch or modify an application during tests unless the adapter's
  behavior requires explicit host validation.
- Preserve existing user settings, secrets, and application startup behavior.
- Keep Stylix optional and preserve the no-Stylix installation path.
- Follow the intent → spec → plan approval gates before implementation.

## Open questions

- Which Electron applications are installed and stable enough on Razer to be
  candidates for a verified adapter?
- Which applications expose a documented or safely observable reload mechanism?
- Should Discord remain unsupported until its crash cause is independently
  resolved, or should it receive only a detection/status adapter first?
