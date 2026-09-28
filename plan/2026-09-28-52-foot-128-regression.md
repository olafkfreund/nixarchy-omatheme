---
status: draft
issue: 52
spec: spec/2026-09-28-52-foot-128-regression.md
---

# Plan: Prevent Foot 1.28 runtime theme regressions

The renderer already emits Foot's supported `[colors-dark]` section. Add a
native parser regression check to the existing terminal runtime test so future
format changes fail in CI.

## Steps

1. `flake.nix`: add `pkgs.foot` to `runtimeTargetsTest.nativeBuildInputs` → verify
   the runtime check can invoke Foot without a graphical session.
2. `tests/runtime-targets.sh`: run
   `foot --check-config --config="$config/omarchy/runtime/foot.ini"` after
   generating the runtime file → verify Foot accepts the complete generated
   configuration.
3. Run the targeted runtime check and the full x86_64 evaluation → verify
   existing terminal, shell, module, and package checks remain green.
4. Commit the test change, push the issue branch, open a PR closing #52, and
   merge only after CI passes.

## Tests

```sh
nix build .#checks.x86_64-linux.runtime --no-link --print-build-logs
nix flake check --system x86_64-linux --no-build --show-trace
nix fmt -- --ci
```

Expected result: Foot's parser exits successfully and all existing checks
remain green.

## Rollback

Revert the implementation commit or remove the Foot parser invocation and
`pkgs.foot` test dependency. The production renderer is unchanged.
