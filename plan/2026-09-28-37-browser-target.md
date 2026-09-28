---
status: draft
issue: 37
spec: spec/2026-09-28-37-browser-target.md
---

# Plan: Opt-in browser theme target

Implement the approved aggregate browser target using Omarchroma's existing
runtime behavior. Keep it disabled by default and leave dependency packaging to
issue #38.

## Steps

1. `modules/nixos.nix`: add `targets.browsers` as a boolean defaulting to
   `false`, include `browsers` in the runtime target command list, and document
   its opt-in and deferred-profile behavior → verify the option evaluates and
   the generated user service contains the command only when enabled.
2. `pkgs/omarchroma-plugin.nix`: extend the existing status watcher and desktop
   status line to read the runtime `browsers` state → verify the generated
   `Panel.qml` contains browser status parsing and display markers.
3. `docs/stylix-integration.md` and `docs/target-matrix.md`: document the
   browser target, its default-off safety boundary, and restart/pending
   semantics → verify the documented option paths remain valid.
4. `tests/options.nix` and the plugin/package checks: add default-off and
   opt-in assertions for the browser target and status UI markers → verify the
   existing option and plugin checks pass.
5. Run formatting, Statix, package checks, option checks, documentation checks,
   and the plugin VM test → verify no unrelated files change.

## Tests

```sh
nix fmt -- --fail-on-change
nix run nixpkgs#statix -- check
NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link .#checks.x86_64-linux.options
NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link .#checks.x86_64-linux.doc-options
NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link .#checks.x86_64-linux.plugin
```

Expected results: all commands exit successfully; browser theming is false in
the default configuration; enabling it adds the runtime target command; and
the plugin build includes browser state handling.

## Rollback

Revert the implementation commit on `feat/37-browser-target`, or remove the
branch before merging. The approved intent, spec, and plan remain as the audit
trail. Runtime users can set `programs.nixarchyThemeEngine.targets.browsers =
false;` before rebuilding if an integration issue is found.
