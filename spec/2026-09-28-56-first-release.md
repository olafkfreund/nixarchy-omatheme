---
status: approved
issue: 56
intent: intent/2026-09-28-56-first-release.md
---

# Spec: Publish the first omatheme release

## Design

Use `v0.1.0` as the first public release of the current merged runtime
engine. The release is a GitHub tag over the verified `main` commit; no new
runtime abstraction or package manager is needed.

Update the existing user-facing documentation in `README.md` and the target
matrix in `docs/target-matrix.md` to describe:

- flake installation and the NixOS module;
- Stylix-enabled and standalone operation;
- rebuild-free live switching;
- the supported runtime targets and their verification status.

Use the existing `checks` in `flake.nix` and shell tests under `tests/` as the
release gate. Add only the smallest missing check needed to prove that a
fresh module evaluation works with Stylix absent and present; do not add a
second test framework.

After the release tag is verified, update Nixarchy's existing
`nixarchy-omatheme` input to the tag and run its normal configuration checks.

## Alternatives rejected

- Keeping a moving `main` commit pin: it does not give users a reproducible
  release boundary.
- Making Stylix mandatory: it breaks Nixarchy installations that do not use
  Stylix.
- Rebuilding on every theme switch: it violates the runtime engine's purpose.
- Adding a new release/test framework: the flake checks and shell tests already
  cover the project.

## Risks

- A release tag can expose documentation or packaging mistakes that a commit
  pin hides.
- Nixarchy's tag update could fail on an unsupported system or stale lock
  input; its configuration checks must pass before merging.
- Runtime target behavior remains dependent on the target application being
  installed and running; unsupported targets must remain clearly documented.

## Verification

- `nix flake check` passes on supported systems.
- Existing runtime shell tests pass.
- A clean Stylix-free module evaluation passes.
- A clean Stylix-enabled module evaluation passes.
- The tagged input evaluates from a fresh checkout.
- Nixarchy checks pass after consuming `v0.1.0`.
