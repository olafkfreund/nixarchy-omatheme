---
status: approved
issue: 22
spec: spec/2026-09-27-22-compact-runtime-status.md
---

# Plan: Compact runtime status on narrow bars

Keep the plugin’s four live status rows and status schema, but shorten their
target labels so the important state values remain visible on narrow bars.

## Steps

1. Inspect the current generated QML patch markers and status-label helpers →
   verify the existing four rows and `Text.ElideRight` markers are unique.
2. Update `pkgs/omarchroma-plugin.nix` with one target-abbreviation helper and
   compact Shell, Terminals, Electron, and Desktop row text → verify every
   current target remains represented and unknown values still pass through.
3. Extend generated-source marker assertions for the abbreviation helper,
   compact row labels, and single-line/elision behavior → verify upstream drift
   fails the plugin build clearly.
4. Run the plugin build and all existing runtime/module checks → verify the
   compact plugin builds and status/runtime behavior remains unchanged.

## Tests

- `nix flake check --no-build --accept-flake-config`
- `nix build .#packages.x86_64-linux.omarchroma-plugin --accept-flake-config`
- `nix build .#checks.x86_64-linux.runtime --accept-flake-config`
- `nix build .#checks.x86_64-linux.desktop --accept-flake-config`
- `nix build .#checks.x86_64-linux.electron --accept-flake-config`
- `nix build .#checks.x86_64-linux.module --accept-flake-config`
- `git diff --check`

Expected result: the plugin keeps all current live status groups, renders more
compact labels, and all existing checks remain green.

## Rollback

Revert the implementation commit for issue #22. The previous full-label status
rows remain functional, and no runtime or status schema changes are involved.
