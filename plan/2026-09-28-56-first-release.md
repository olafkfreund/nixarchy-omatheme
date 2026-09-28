---
status: draft
issue: 56
spec: spec/2026-09-28-56-first-release.md
---

# Plan: Publish the first omatheme release

The current merged runtime engine will be released as `v0.1.0`. Existing
flake checks and shell tests remain the release gate. Documentation will make
the Stylix and standalone paths explicit, and Nixarchy will consume the
verified release tag after publication.

## Steps

1. `README.md`, `docs/target-matrix.md`: document `v0.1.0` installation,
   Stylix-enabled operation, Stylix-free operation, live switching, and the
   verified target matrix → verify links and examples from a clean checkout.
2. `flake.nix` and `tests/`: run the existing no-Stylix and Stylix evaluation
   checks; add only a missing assertion if the current checks do not prove both
   module paths → verify with `nix flake check` and the existing test scripts.
3. Repository release: run the complete checks on the release branch, merge
   the implementation PR, and create the annotated GitHub tag/release
   `v0.1.0` from the verified commit → verify a fresh `nix flake check` resolves
   the tag.
4. Nixarchy's existing `nixarchy-omatheme` input: replace the commit pin with
   `v0.1.0`, refresh only the intended lock entries, and run Nixarchy's normal
   configuration checks → verify the tag is used and all host checks pass.
5. Razer runtime acceptance: rebuild from the tagged Nixarchy input and test a
   live theme switch across the supported terminal/editor targets → verify no
   NixOS rebuild is required and the service remains active.

## Tests

- `nix flake check`
- Existing scripts under `tests/`
- Nixarchy's configured lint and host evaluation checks
- Razer: `nixos-rebuild switch --flake .#razer --no-write-lock-file`
- Razer: `systemctl --user is-active hyprchromad`
- Razer: `foot --check-config` and editor runtime-file checks

## Rollback

- Before release publication, revert the implementation PR.
- If the tagged Nixarchy input fails, restore the previous commit pin and
  lockfile entry in a separate revert PR.
- On Razer, select the previous NixOS generation with `nixos-rebuild
  switch --rollback` if the runtime verification fails.
