---
status: approved
issue: 12
spec: spec/2026-09-26-12-shell-runtime-targets.md
---

# Plan: Shell and CLI runtime theme targets

Implement the first verified shell runtime wave for Starship, Bash, Zsh, and
Fish while preserving Stylix/Home Manager ownership and leaving unverified CLI
applications inert.

## Steps

1. `pkgs/hyprchroma-shell`: add a renderer that validates the active palette,
   writes `starship.toml`, `shell-theme.sh`, and native `shell-theme.fish` atomically through
   `hyprchroma-state`, and emits per-target shell status → verify deterministic
   output and shell syntax in temporary XDG homes.
2. `modules/nixos.nix`: add shell target options, runtime directories, and
   post-`linkGeneration` Starship ownership bridging. Add idempotent `mkAfter`
   Bash/Zsh/Fish startup and prompt hooks without replacing existing shell
   configuration → verify module evaluation with Stylix present/absent and
   shell combinations enabled/disabled.
3. `pkgs/hyprchroma.nix`: install the shell renderer, add CLI dispatch, and
   invoke shell synchronization from the existing theme fan-out → verify help
   output, daemon synchronization, and failure propagation.
4. `pkgs/omarchroma-plugin.nix`: watch the shell status file and display
   Starship/Bash/Zsh/Fish states beside terminal and Electron states → verify
   generated QML markers and plugin manifest validation.
5. Tests and documentation: add temporary-XDG tests for valid/malformed
   Starship files, store-linked refusal, shell-safe values, prompt reload
   states, and unsupported CLI no-write behavior. Update the target matrix,
   README, and Stylix integration guide → verify `nix fmt`, `git diff --check`,
   and `nix flake check --all-systems`.
6. Razer acceptance: build and temporarily activate the branch, verify the
   Starship bridge and Bash/Zsh/Fish runtime hooks, then restore the recorded
   generation and confirm `/home/olafkfreund/.config/nixos` is clean.
7. Review and merge: push the branch, open a PR linked to issue #12, wait for
   CI and Razer acceptance, then merge only after all checks pass.

## Tests

- `nix fmt`
- `git diff --check`
- `nix flake check --all-systems`
- Engine and plugin builds
- Starship TOML validation in temporary XDG homes
- Bash, Zsh, and Fish syntax/startup checks
- Store-linked and malformed configuration refusal checks
- Unsupported CLI no-write check
- Temporary Razer system build and activation
- Clean NixOS configuration worktree check

## Rollback

- Disable the shell target options.
- Rebuild the consuming NixOS configuration to remove startup hooks and
  runtime bridges.
- Restore the previous Starship file and shell configuration from the captured
  pre-test state.
- Remove only generated files below `~/.config/omarchy/runtime/` and
  `$XDG_STATE_HOME/hyprchroma` if required.
- Revert the implementation PR if shell startup behavior is incorrect.
