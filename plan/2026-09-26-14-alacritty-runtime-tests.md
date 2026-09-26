---
status: draft
issue: 14
spec: spec/2026-09-26-14-alacritty-runtime-tests.md
---

# Plan: Audit Alacritty bridge and add runtime test matrix

This task keeps Alacritty as a Home Manager/Stylix-owned declarative wrapper
with a user-owned runtime boundary. It does not add an Alacritty palette
renderer until the source audit proves that one is needed and safe. The tests
will run in temporary homes and will not modify `/home/olafkfreund/.config/nixos`.

## Steps

1. `modules/nixos.nix`, pinned Omarchy source, and `examples/stylix/alacritty.nix`:
   trace the Alacritty file flow and record the exact ownership/reload behavior
   → verify with source inspection and a module-evaluation assertion that the
   activation runs after `linkGeneration` and copies symlinked generated content
   to a regular user-owned file.
2. `docs/target-matrix.md`, `docs/stylix-integration.md`, and `README.md`:
   correct Alacritty’s status and remove contradictory claims about a supplied
   runtime import or live reload → verify all Alacritty documentation describes
   the same bridge and fallback semantics.
3. `tests/runtime-targets.sh`: add a dependency-free temporary-home test that
   copies the packaged shell renderer beside fixture `hyprchroma-palette` and
   `hyprchroma-state` helpers, renders two fixture palettes, and checks atomic
   runtime outputs, Starship palette markers, Bash/Fish syntax, status JSON, and
   changed output between palettes → verify with `bash tests/runtime-targets.sh`.
4. `flake.nix` and package checks: run the runtime test from the existing flake
   check path without requiring a graphical session or installed Alacritty →
   verify `nix flake check --all-systems` and both package builds.
5. Razer acceptance test: build the branch as an extended `razer` system,
   activate with `switch-to-configuration test`, verify the Alacritty file
   boundary and a real Omarchy theme switch, then restore the prior generation
   and test-created files → verify the original generation, theme, runtime file
   set, and user service are restored.
6. Commit the implementation, push the branch, open a PR linking issue #14 and
   the three artifacts, wait for CI, and merge only after all checks pass.

## Tests

```sh
bash tests/runtime-targets.sh
nix flake check --all-systems
nix build .#hyprchroma .#omarchroma-plugin
```

The manual Razer test uses the exact merged system expression and does not edit
the NixOS configuration repository.

## Rollback

Before Razer activation, record `/run/current-system`, the active Omarchy theme,
and the runtime directory listing. Restore the recorded system with its
`switch-to-configuration test` entry point, restore the original theme, and
remove only files created by the temporary test. Revert the branch commits or
close the PR if CI or manual validation fails.
