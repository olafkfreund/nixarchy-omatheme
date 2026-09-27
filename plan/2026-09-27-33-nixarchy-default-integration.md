---
status: draft
issue: 33
spec: spec/2026-09-27-33-nixarchy-default-integration.md
---

# Plan: Integrate omatheme into Nixarchy defaults

Implement the approved two-owner integration across the standalone
nixarchy-omatheme repository and the upstream Nixarchy repository. The
standalone module remains complete for direct users; Nixarchy owns the default
plugin link while omatheme owns the runtime engine and reload service.

## Steps

1. `nixarchy-omatheme/modules/nixos.nix`: add
   `programs.nixarchyThemeEngine.managePlugin`, defaulting to `true`, and gate
   the plugin-file Home Manager activation on it → verify existing standalone
   behavior remains unchanged and the option evaluates in the module check.
2. `nixarchy-omatheme/flake.nix` and tests: add a targeted module assertion
   proving `managePlugin = false` leaves the plugin activation absent while the
   daemon/plugin-enable service remains present → verify
   `nix flake check --all-systems --no-build`.
3. Commit, push, and merge the standalone module change after CI passes → use
   the merged commit as the pinned Nixarchy input revision.
4. `nixarchy/flake.nix`: add a pinned `nixarchy-omatheme` input following
   Nixpkgs and Home Manager, then update `flake.lock` → verify lock metadata
   resolves the package and module without a second Nixpkgs/Home Manager node.
5. `nixarchy/modules/nixos.nix`: import the omatheme NixOS module and set its
   defaults from `programs.nixarchy.user`; enable it only when Nixarchy has a
   configured desktop user and set `managePlugin = false` → verify a null-user
   system does not create an invalid Home Manager user entry.
6. `nixarchy/modules/home.nix`: add the pinned `omarchroma-plugin` package to
   `defaultPluginSet` under `omatheme`, and enable `defaultPlugins.omatheme`
   by default → verify the manifest id and source resolve to one declared
   plugin owner.
7. `nixarchy/tests`: add evaluation and runtime assertions for the default
   plugin, engine options, Stylix-free mode, one plugin writer, and the daemon
   service → verify the existing plugin test and a Nixarchy VM test.
8. `nixarchy/README.md` or the relevant integration documentation: document
   that omatheme is included by default, Stylix remains optional, and the
   plugin ownership split is intentional → verify links and option names.
9. Run both repositories' formatters/checks, then run the Razer smoke test:
   confirm `hyprchromad.service`, the Omarchy Shell registry entry, and
   `omarchy theme set` switch themes without a rebuild → open the upstream PR
   linking Nixarchy issue #1023 and this project's issue #33.

## Tests

- `nixarchy-omatheme`: `git diff --check`.
- `nixarchy-omatheme`: `nix flake check --all-systems --no-build`.
- `nixarchy`: `nix fmt -- --check` or the repository's documented formatter
  check, followed by `nix flake check --all-systems --no-build`.
- Nix evaluation assertions for `omarchy` and null-user configurations.
- Plugin test assertions for the manifest id, declared source, and absence of
  duplicate activation writers.
- Stylix-free Nixarchy evaluation and runtime VM/Razer smoke test.
- HTTP/runtime verification only after the upstream Pages/CI jobs complete.

## Rollback

Revert the Nixarchy integration PR and remove its flake input to restore the
previous default set. Standalone users remain unaffected. If the module API
must be rolled back, restore the default `managePlugin = true` behavior and
remove the upstream `managePlugin = false` setting before rebuilding.
