---
status: approved
issue: 39
author: olafkfreund
---

# Intent: Expose palette capture and restore in the theme plugin

## Problem

The runtime engine can apply a selected Omarchy palette across its supported
targets, but users cannot conveniently save the current palette state before
trying another theme or restore a previous state from the Nixarchy menu. A
manual copy of generated files is unsafe because the active palette has
multiple derived target files and some applications need reload handling.

## Proposed outcome

Users can capture the current runtime palette as a named, user-owned snapshot
and restore it through the theme plugin or an equivalent user command. Restore
reuses the normal theme application path so supported applications update
together, status remains accurate, and no NixOS rebuild is required.

## Affected users and systems

- NixOS users of the Omarchroma runtime engine and Nixarchy plugin.
- Stylix and non-Stylix installations.
- The active palette, runtime target files, daemon, and plugin menu.
- User-owned state under `~/.config/omarchy` or the engine runtime directory.

## Constraints

- Snapshots must live outside the Nix store and be writable by the session
  user.
- Capture and restore must not overwrite declarative Home Manager or Stylix
  source files.
- Restore must use the existing atomic theme-switch path and target status
  reporting.
- Snapshot names and paths must be validated; restoration must not allow path
  traversal or arbitrary file writes.
- Existing theme switching must continue to work when no snapshots exist.
- Do not require a rebuild, pip package, or external database service.

## Open questions

- Should snapshots store only the canonical palette or also derived runtime
  files and target enablement state?
- Should the plugin expose a fixed small set of actions or support arbitrary
  user-provided snapshot names?
- What should happen when a snapshot was captured with targets that are no
  longer enabled or installed?
