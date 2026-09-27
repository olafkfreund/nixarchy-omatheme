---
status: approved
issue: 18
spec: spec/2026-09-27-18-desktop-runtime-acceptance.md
---

# Plan: Desktop runtime target acceptance

Implement the approved desktop acceptance matrix without changing the runtime
target protocol or requiring Stylix. CI will use isolated fixtures; Razer will
only provide an installed-target smoke check.

## Steps

1. Inspect the pinned `omarchroma` source and current packaged target scripts to
   identify each target’s real artifact, external command boundary, and status
   result. Record any necessary test-boundary adjustment in this plan before
   implementation → verify the five target commands are mapped without adding
   a new adapter.
2. Add `tests/desktop-runtime.sh` using temporary XDG/HOME directories and
   minimal command stubs. Exercise GTK, Qt/KDE, Dark Reader, Pear, and Flatpak
   with both palette fixtures; assert enabled output, safe disablement, and
   unavailable/restart-required reporting where the target cannot run headless
   → verify the script exits zero and leaves unrelated fixtures unchanged.
3. Add the `desktop` flake check in `flake.nix`, reusing the existing package
   and test setup style → verify the check evaluates and builds on x86_64-linux.
4. Add only the documentation or status-output clarification required by the
   observed behavior; keep Stylix optional and preserve existing target matrix
   semantics → verify `git diff --check` and no user NixOS config changes.
5. Run the full local checks, then verify the exact built package on Razer and
   read the existing target status/prerequisites without toggling live targets,
   installing software, or changing Flatpak permissions → verify existing
   runtime, Electron, module, and new desktop checks all pass and the NixOS
   config repository is clean.

## Tests

- `nix flake check --no-build --accept-flake-config`
- `nix build .#checks.x86_64-linux.desktop`
- `nix build .#checks.x86_64-linux.runtime`
- `nix build .#checks.x86_64-linux.electron`
- `nix build .#checks.x86_64-linux.module`
- Razer host smoke: built package version check plus read-only target status and
  prerequisite inspection.

Expected result: all deterministic checks pass; Razer reports only the targets
available on that host and does not modify `/home/olafkfreund/.config/nixos`.

## Rollback

Revert the implementation commit(s) for issue #18. The existing runtime,
Electron, and module checks remain independent, and removing the `desktop`
flake check removes the new acceptance gate without affecting runtime behavior.
