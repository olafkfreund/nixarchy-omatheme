---
status: approved
issue: 63
author: olafkfreund
follows: spec/2026-09-28-53-editor-theme-targets.md
---

# Intent: LazyVim, Neovim and Vim follow live desktop theme changes

## Problem

The #53 editor targets promise that a live desktop theme switch reaches
Neovim and Vim. On the owner's host (Razer, Neovim 0.12.6, LazyVim) it does
not: after `omarchy theme set <name>`, a running LazyVim session keeps the
old colours until the owner runs `:colorscheme <name>` by hand or restarts.
New LazyVim sessions do pick up the new theme, but only because the owner's
own `~/.config/nvim/lua/plugins/theme.lua` links to Omarchy's
`current/theme/neovim.lua`; Omarchy itself never signals Neovim.

What is wrong in the shipped code:

1. The Neovim bridge never loads under LazyVim. It is installed under
   `~/.local/share/nvim/site/pack/nixarchy/start/` (`modules/nixos.nix:340`),
   and lazy.nvim's default `performance.reset_packpath = true` sets
   `packpath=$VIMRUNTIME`. On the owner's host
   `exists(':OmarchyThemeReload') == 0`.
2. Where the bridge does load (plain Neovim), it re-applies 35 fixed
   highlight groups after every `ColorScheme` event (`modules/nixos.nix:83`).
   That overrides a colorscheme the user picks by hand and drops its
   bold/italic attributes. Treesitter, LSP semantic-token and plugin groups
   are not covered and can keep the old palette, unless they happen to link
   to one of the 35 groups.
3. Neovim never receives the theme's light/dark mode
   (`render_neovim(colors)` in `pkgs/hyprchroma-editors`).
4. The bridges read `~/.config/omarchy/runtime/...` while the renderer
   honours `XDG_CONFIG_HOME`; the install path hard-codes `.local/share`
   instead of honouring `XDG_DATA_HOME`.
5. In Vim, the `ColorScheme` autocmd sources a file that begins with
   `highlight clear`, wiping a colorscheme the user just chose.
6. Both bridges reload once more one second after startup, because the
   change timestamp is not recorded at the first load.
7. `tests/editors-runtime.sh` runs `nvim -u NONE` / `vim -Nu NONE` and
   applies the generated files by hand, so it passes while the installed
   bridges are broken.

## Proposed outcome

Observable by the owner:

- Within 2 seconds of a desktop palette change (theme switch, palette
  restore, or standalone-mode palette update), every LazyVim and plain
  Neovim session started after this change is installed shows the new
  theme, with no restart and no rebuild.
- What changes on screen: editor background and text, cursor line, line
  numbers, selection, search, popup menus, floating windows, statusline,
  syntax and Treesitter highlighting, and LSP diagnostics, with the light or
  dark mode of the new theme.
- When the active Omarchy theme ships its own Neovim colorscheme and that
  colorscheme is available in the running session, the result looks the
  same as starting Neovim fresh on that theme.
- When it is not available, the session still follows the desktop palette
  for the surfaces listed above, without errors and without network access.
- A colorscheme the user picks by hand during a session stays until the
  next desktop palette change.
- Classic Vim with timer support follows the same rules for its built-in
  highlight groups. Vim without timers updates at startup and on
  `:OmarchyThemeReload`, as #53 already scoped.
- `nix flake check` fails when the bridge does not load under lazy.nvim's
  default settings, or when a palette change does not reach a running
  editor.

Out of scope: sessions already running when this change is first deployed
(they need one restart), and plugins that cache their own colours outside
highlight groups beyond the statusline.

## Affected users and systems

- `modules/nixos.nix`: the Neovim and Vim bridges and their install paths.
- `pkgs/hyprchroma-editors`: the generated Neovim and Vim theme files.
- `tests/editors-runtime.sh` and the `editors` check in `flake.nix`.
- `docs/target-matrix.md` and `README.md` editor rows.
- Users of `programs.nixarchyThemeEngine` with Home Manager present and
  `targets.neovim` or `targets.vim` enabled (both default to `true`), for
  `cfg.user` only, including the Nixarchy ISO path.
- Neovim set-ups that install the bridge alongside: a user-managed LazyVim
  or plain `~/.config/nvim`, Home Manager `programs.neovim`, NixVim and nvf,
  and configurations where `~/.config/nvim` is one whole-directory symlink.
- The owner's host (Razer) for the final runtime check.

## Constraints

- Must not write to or edit user-owned editor configuration (`init.lua`,
  `lua/plugins/*`, `.vimrc`, or a Home Manager / NixVim / nvf generated
  tree), and must not collide with a whole-directory `nvim` symlink.
- Must work with Stylix imported and absent, and offline: no plugin
  installs or network access while a session is running.
- Must not require a Neovim RPC listener or Vim client-server support; the
  #53 rejection of RPC as the primary mechanism stands.
- Must keep the generated runtime file paths and the `editors.json` status
  file, so `hyprchroma editors` and the daemon keep working.
- Builds and the runtime check run on the owner's host only.

## Evidence gathered for the spec

Read-only checks and scratchpad experiments; they inform the design but are
not requirements.

- `stdpath('data')/site` stays on lazy.nvim's runtimepath; a probe file in
  `~/.local/share/nvim/site/plugin/` was loaded under the owner's LazyVim.
- In an isolated lazy.nvim session, re-reading a changed Omarchy
  `neovim.lua` and re-applying its colorscheme switched `Normal.bg` from
  `#0b1b2b` to `#300000` without a restart.
- In the owner's live LazyVim session, after a desktop switch, running
  `:colorscheme aether` by hand applied the new theme's colours.
- The 23 Omarchy themes reference 15 Neovim colorscheme plugins; 5 are
  installed on the owner's host.

## Open questions

1. **Startup precedence.** If the user's own config sets a colorscheme at
   startup (for example the owner's `lua/plugins/colorscheme.lua`, which
   hard-codes base16 Nord), should the desktop theme win at startup, or only
   on the next live switch? Separately: will the owner remove that file, or
   must acceptance pass with it in place? Nixarchy will not edit it.
2. **Missing colorschemes.** Is the palette-derived look acceptable for as
   long as a theme's own colorscheme plugin is not installed, possibly
   indefinitely? Or should Nixarchy offer an option to ship Omarchy's
   Neovim colorscheme plugins so every theme renders natively offline?
3. **Declarative Neovim.** Are Home Manager `programs.neovim`, NixVim and
   nvf required to switch live, best-effort, or out of scope when they
   isolate the runtimepath?
4. **Stylix mode.** When `stylix.mode` resolves to `"stylix"`, should the
   editor bridges still follow live Omarchy switches, or stay passive so
   Stylix owns editor colours?
5. **What counts as a change.** Should re-selecting the same theme, or a
   font-only update, override a colorscheme the user picked by hand?
