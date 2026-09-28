---
status: draft
issue: 38
spec: spec/2026-09-28-38-runtime-dependencies.md
---

# Plan: Package Omarchroma runtime dependencies on NixOS

Implement the approved dependency packaging design on the `feat/38-runtime-dependencies`
branch. Browser synchronization remains opt-in; the package supplies its
Python dependency declaratively and does not install anything at activation
time.

## Steps

1. `pkgs/hyprchroma.nix`: add a Nix-provided Python runtime built with
   `python3.withPackages (ps: [ ps.plyvel ])`; use it for the wrapper's Python
   invocations and trusted runtime path → verify the derivation evaluates.
2. `flake.nix`: add a small package dependency check that runs the packaged
   interpreter and imports `plyvel` → verify the check fails if the runtime
   environment loses the dependency.
3. `docs/stylix-integration.md` and `docs/target-matrix.md`: document that
   browser support is packaged but remains opt-in, and list the host GTK,
   libadwaita, and Qt theme assets only where target behavior requires them →
   verify examples match the module options.
4. Existing module/runtime checks: keep browser default-off behavior and verify
   enabled target command generation alongside shell, terminal, desktop, and
   Electron checks → verify all checks build successfully.

## Tests

Run:

```sh
nix fmt -- --fail-on-change
NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link .#packages.x86_64-linux.default
NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link .#checks.x86_64-linux.package-dependencies
NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link .#checks.x86_64-linux.module
NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link .#checks.x86_64-linux.runtime
NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link .#checks.x86_64-linux.desktop
NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link .#checks.x86_64-linux.electron
nix run nixpkgs#statix -- check
```

Expected results are successful builds and formatting. Existing unrelated
Statix warnings are recorded rather than fixed in this issue.

## Rollback

Revert the implementation commit. This removes the packaged `plyvel` runtime
and dependency check while leaving the approved intent, spec, and issue
history intact. Browser synchronization remains unavailable unless the
dependency is restored.
