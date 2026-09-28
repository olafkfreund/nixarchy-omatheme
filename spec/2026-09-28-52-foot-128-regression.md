---
status: approved
issue: 52
intent: intent/2026-09-28-52-foot-128-regression.md
---

# Spec: Prevent Foot 1.28 runtime theme regressions

## Design

Extend the existing `tests/runtime-targets.sh` check to run Foot's native
configuration parser against the generated
`$XDG_CONFIG_HOME/omarchy/runtime/foot.ini`:

```sh
foot --check-config --config="$config/omarchy/runtime/foot.ini"
```

Add `pkgs.foot` to the `runtimeTargetsTest` native build inputs in `flake.nix`.
Keep `pkgs/hyprchroma-terminals` unchanged because it already emits the
Foot 1.28-compatible `[colors-dark]` section.

## Alternatives rejected

- Checking only for `[colors-dark]`: does not validate Foot option names or
  syntax.
- Reimplementing Foot's parser in shell: duplicates upstream behavior.
- Changing the renderer again: the production format is already fixed.

## Risks

The Nixpkgs Foot version could reject an unrelated option in the generated
fixture. This would correctly expose compatibility drift in CI and can be
diagnosed from Foot's parser output.

## Verification

- `nix flake check --system x86_64-linux --no-build --show-trace`
- `nix build .#checks.x86_64-linux.runtime --no-link --print-build-logs`
- The runtime test must pass with Foot's parser and continue to verify
  idempotent terminal rendering.
