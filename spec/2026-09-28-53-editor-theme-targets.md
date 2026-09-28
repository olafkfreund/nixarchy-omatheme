---
status: draft
issue: 53
intent: intent/2026-09-28-53-editor-theme-targets.md
---

# Spec: Add live Vim and Neovim theme targets

## Design

Add an editor renderer to the existing `hyprchroma` package. It will consume
the canonical runtime palette and generate:

- `~/.config/omarchy/runtime/neovim-theme.lua`
- `~/.config/omarchy/runtime/vim-theme.vim`
- `~/.local/state/hyprchroma/editors.json`

Expose `targets.neovim` and `targets.vim` in `programs.nixarchyThemeEngine`.
The existing theme and font hooks will run the editor renderer through the
daemon's normal synchronization path.

Install small runtime bridge plugins through Home Manager:

- Neovim: a `pack/*/start` Lua plugin that applies highlights at startup,
  watches the generated file, and reapplies after `ColorScheme` events.
- Vim: a `pack/*/start` Vimscript plugin that sources the generated file at
  startup, provides `:OmarchyThemeReload`, and uses a timer when available.

LazyVim, NixVim, and nvf are Neovim consumers and do not receive separate
targets. Stylix remains responsible for declarative initial configuration;
the runtime bridges apply the active Omarchy palette after a live switch.
The bridge will not require TCP RPC, Vim client-server support, or a specific
colorscheme plugin.

## Alternatives rejected

- A separate LazyVim target: LazyVim is a Neovim configuration layer, so a
  duplicate target would create two implementations for one editor.
- External Neovim RPC as the primary mechanism: it requires a running listener,
  introduces trusted-socket security concerns, and does not cover all editor
  sessions.
- Rewriting user-managed Neovim or Vim configuration files: this would fight
  Home Manager, Stylix, NixVim, and user dotfiles.
- A new palette source: the editor renderer should reuse the existing
  Omarchy/standalone palette resolution.

## Risks

- A colorscheme loaded after the bridge may overwrite some groups; the Neovim
  `ColorScheme` hook mitigates this, but plugins with private namespaces may
  require future explicit mappings.
- Classic Vim installations without timers reload on startup and through the
  explicit command only.
- LazyVim may change plugin highlights after startup; standard global groups are
  supported first, with plugin-specific groups added only when verified.

## Verification

- Module evaluation passes with Stylix imported and absent.
- Renderer fixtures produce deterministic Lua, Vimscript, and status JSON.
- Neovim headless test confirms generated highlights are applied.
- Vim headless test confirms generated highlights are applied.
- Re-running the renderer with the same palette is idempotent.
- Runtime theme switching on Razer changes editor colors without rebuilding.
- Existing desktop, terminal, shell, Electron, browser, and plugin checks stay
  green.
