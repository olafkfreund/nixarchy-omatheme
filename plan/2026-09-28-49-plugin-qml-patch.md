---
status: draft
issue: 49
spec: spec/2026-09-28-49-plugin-qml-patch.md
---

# Plan: Replace the inline plugin QML rewrite

The approved change replaces the embedded Python source generator in
`pkgs/omarchroma-plugin.nix` with a checked-in patch applied to the pinned
Omarchroma `Panel.qml`. Nix retains only engine-path substitutions and package
installation. Runtime behavior and the plugin interface remain unchanged.

## Steps

1. Extract the current generated `Panel.qml` changes into
   `pkgs/patches/omarchroma-panel.patch` → verify the patch applies to the
   pinned Omarchroma source.
2. Remove the embedded Python rewrite from `pkgs/omarchroma-plugin.nix` and
   apply the patch through the derivation patch phase → verify the derivation
   still substitutes Nix store paths.
3. Build the plugin and default engine packages → verify both complete without
   patch or QML source errors.
4. Run the existing palette-actions, desktop, electron, runtime-target, and
   plugin-enable checks → verify current behavior is preserved.
5. Inspect the diff and publish a PR closing issue #49 → verify the branch is
   clean and CI starts.

## Tests

```sh
nix build .#packages.x86_64-linux.omarchroma-plugin --no-link --print-build-logs
nix build .#packages.x86_64-linux.hyprchroma --no-link --print-build-logs
nix build .#checks.x86_64-linux.palette-actions .#checks.x86_64-linux.desktop \
  .#checks.x86_64-linux.electron .#checks.x86_64-linux.runtime \
  .#checks.x86_64-linux.plugin-enable --print-build-logs
```

## Rollback

Revert the implementation commit. The previous inline rewrite remains
available in Git history and the existing Omarchroma package pin is unchanged.
