---
status: approved
issue: 12
intent: intent/2026-09-26-12-shell-runtime-targets.md
---

# Spec: Shell and CLI runtime theme targets

## Design

Add a `hyprchroma-shell` renderer beside the existing terminal and Electron
adapters. It writes only user-owned files below
`~/.config/omarchy/runtime/` and records per-target state below
`$XDG_STATE_HOME/hyprchroma/shell.json`.

The first wave has three layers:

1. **Starship:** Home Manager remains the owner of the user’s declarative
   Starship structure. The NixOS module bridges a store-linked Starship file
   to a regular user-owned base template and points shell initialization at a
   generated runtime configuration. The renderer preserves the base TOML and
   replaces only a marked `palette = "hyprchroma"` selection and the generated
   `[palettes.hyprchroma]` block. The active prompt then reads the current
   palette without rebuilding the host.
2. **Bash, Zsh, and Fish:** the module adds small `mkAfter` startup hooks that
   source a generated `shell-theme.sh` file. The file contains only validated
   color environment variables and shell-safe exports. Prompt hooks reload the
   file when its mtime changes where the shell supports a prompt event; the
   status distinguishes prompt-refresh from new-shell-only behavior.
3. **CLI registry boundary:** fzf, bat, btop, yazi, and tmux are not mutated by
   the first wave. Each becomes a separate registry entry only after its
   configuration format and reload mechanism are verified. Unsupported entries
   report `unsupported` and perform no application-file writes.

Theme hooks invoke the shell renderer in the same synchronization fan-out as
the desktop and terminal adapters. Atomic state writes use the existing
`hyprchroma-state` helper. Existing shell configuration, aliases, modules,
and Stylix-generated structure remain intact.

The runtime environment contract is deliberately small: palette-derived
variables are exposed through the generated file, while application-specific
options remain in the declarative configuration. This prevents a theme switch
from replacing user shell behavior.

## Alternatives rejected

### Rewrite the user’s Starship or shell configuration on every theme switch

Rejected because Home Manager/Stylix owns the declarative structure and a
runtime rewrite would overwrite user preferences or leave a store symlink
broken.

### Use environment variables only

Rejected for Starship because its palette and style definitions live in its TOML
configuration. Environment variables remain useful for shell-facing color
exports, but cannot replace the Starship configuration boundary.

### Add every CLI application immediately

Rejected because btop, yazi, tmux, fzf, and bat have different configuration
ownership and reload behavior. A registry with explicit verification prevents
false claims of “all at once” support.

### Restart every shell and terminal process automatically

Rejected because killing or replacing interactive sessions loses user state.
Prompt-time reload is used where safe; other processes report their actual
restart requirement.

## Risks

- A Starship file may not contain the expected palette structure; the bridge
  must fail closed and report unavailable rather than produce invalid TOML.
- Shell startup hooks can conflict with existing user hooks; they must use
  append semantics and be idempotent.
- Existing shells may cache prompt functions or environment values; status must
  distinguish refreshed prompts from new shells.
- Fish may not be enabled on every host; absence must be a no-op.
- A malformed palette value could become shell syntax; all generated values
  must be validated before writing.
- Store-linked Home Manager files must be copied only after `linkGeneration`,
  matching the existing terminal bridge ownership model.

## Verification

- Evaluate the NixOS module with Stylix present and absent, with Bash/Zsh/Fish
  combinations enabled and disabled.
- Render Starship and shell files in temporary XDG homes; validate TOML and
  shell syntax and verify unrelated configuration remains unchanged.
- Start Bash, Zsh, and Fish test sessions, switch the palette, and verify the
  prompt/environment status without restarting the session where supported.
- Verify missing or store-linked Starship configuration fails closed.
- Verify unsupported CLI registry entries create no application files.
- Build the engine and plugin, validate status output, and check the menu’s
  shell status reader.
- On Razer, activate a temporary system generation, test the login shell and
  Starship boundary, restore the original generation, and confirm the NixOS
  configuration worktree is clean.
