---
status: approved
issue: 63
intent: intent/2026-11-12-63-editor-live-theme.md
---

# Spec: LazyVim, Neovim and Vim follow live desktop theme changes

## Decisions on the intent's open questions

The intent was approved with its open questions unanswered. This spec takes
the defaults below; each is a review point for the owner.

| # | Question | Default taken here |
| --- | --- | --- |
| 1 | Startup precedence | The user's own config wins at startup. The bridge applies a theme at startup only when nothing set one: `g:colors_name` is unset **and** `Normal` has no foreground or background (covers configs, including Stylix/base16 set-ups, that set highlights without a colorscheme name). Live switches after startup always apply. Acceptance passes with the owner's `colorscheme.lua` in place, because `theme.lua` already wins the LazyVim merge on Razer. |
| 2 | Missing colorschemes | The palette-derived `omarchy` colorscheme is used for as long as the theme's own plugin is unavailable. Shipping Omarchy's colorscheme plugins is out of scope; it can be a follow-up option. |
| 3 | Declarative Neovim | Best-effort. Home Manager `programs.neovim` is expected to work (it keeps `stdpath('data')/site` on the runtimepath); a module-evaluation fixture proves the files install without collisions, but a wrapped-Neovim runtime run is not in CI. NixVim and nvf are documented as best-effort and not tested. |
| 4 | Stylix mode | Editors follow live switches in both modes, like every other runtime target in `docs/target-matrix.md`. Stylix keeps the declarative startup config. |
| 5 | What counts as a change | Only a change in the generated palette content. Re-selecting the same theme or a font-only update produces identical renderer output (already asserted by the idempotence test) and does nothing. A palette change without an Omarchy theme change (palette restore, standalone update) is applied with the palette-derived `omarchy` colorscheme, because the theme's own colorscheme would not reflect it. |

## Design

### 1. Install the Neovim bridge where lazy.nvim keeps it

Move the bridge from
`.local/share/nvim/site/pack/nixarchy/start/nixarchy-theme/plugin/nixarchy-theme.lua`
to `xdg.dataFile."nvim/site/plugin/nixarchy-theme.lua"`, and add
`xdg.dataFile."nvim/site/colors/omarchy.lua"`. `stdpath('data')/site` stays
on lazy.nvim's reset runtimepath (probe-verified on Razer), and `xdg.dataFile`
follows Home Manager's `xdg.dataHome` instead of hard-coding `.local/share`.
Home Manager removes the old `pack/` link when it is no longer declared.
Nothing is written under `~/.config/nvim`, so whole-directory `nvim` symlinks
and user-owned configs are untouched.

The Lua and Vim sources move out of the inline `pkgs.writeText` strings in
`modules/nixos.nix` into files installed by `pkgs/hyprchroma.nix` under
`$out/share/hyprchroma/editors/`, so the tests exercise the exact shipped
files.

### 2. Neovim bridge behaviour

- **Guarded load.** `vim.g.loaded_nixarchy_theme_bridge` stops double
  loading; autocmds live in one cleared augroup; the timer handle is kept at
  module scope and stopped on `VimLeavePre`.
- **Paths.** The runtime file is
  `($XDG_CONFIG_HOME or ~/.config)/omarchy/runtime/neovim-theme.lua`, and the
  Omarchy theme spec is
  `($XDG_STATE_HOME or ~/.local/state)/omarchy/current/theme/neovim.lua`,
  matching the renderer. A missing runtime file is a silent no-op.
- **Change detection.** `vim.fn.timer_start(500, …, {repeat = -1})`, which
  runs on the main loop (a raw `vim.uv` timer callback is a fast-event
  context where `:colorscheme` raises `E5560`). Each tick `fs_stat`s the
  runtime file, comparing `mtime.sec` and `mtime.nsec` separately; when it
  moved, the bridge reads the contents and compares them with the last
  applied contents. The mtime is always recorded; the contents are recorded
  only after a successful apply, and a failed apply sets a `pending` flag that
  is retried on every tick until it succeeds, with no further file change
  needed. At startup the bridge records the mtime and contents as the
  baseline, whether or not it applies a theme, so the first tick does nothing.
  While in command-line mode (`mode() == "c"`) a pending apply waits.
- **No `ColorScheme` overlay.** The autocmd that re-applied 35 groups after
  every `:colorscheme` is removed. A colorscheme the user picks by hand stays
  until the palette content changes.
- **Startup.** The bridge runs the apply step at `VimEnter` only under the
  startup rule in decision 1; otherwise it just records the baseline.
- **Apply** (all calls `pcall`ed and silent):
  1. Set the mode: `vim.g.colors_name = nil`, then `vim.o.background` from
     the runtime file's `mode`, so changing `background` cannot re-source the
     previous colorscheme.
  2. Decide the source. The native path is used only when Omarchy's
     `neovim.lua` exists, its contents changed since the last apply (a theme
     switch, not a palette-only change), and it names a colorscheme via the
     `LazyVim/LazyVim` entry's `opts.colorscheme`. Otherwise go to step 5.
  3. If lazy.nvim is loaded: re-read the spec the way lazy.nvim's own config
     reloader does (`require("lazy.core.plugin").load()`), so a `theme.lua`
     that links to Omarchy's `neovim.lua` yields the new merged `opts`. Find
     the theme plugin in `require("lazy.core.config").plugins` by `name`,
     full repository slug or basename; if it is `_.installed`, run
     `require("lazy.core.loader").reload(plugin)`. Never install or fetch a
     plugin. A failure here falls through to step 4.
  4. Run `vim.cmd.colorscheme(name)`. This covers plugins already on the
     runtimepath in plain Neovim and colorschemes that read their colours at
     load time. If it fails, go to step 5.
  5. Run `vim.cmd.colorscheme("omarchy")`.
- **`:OmarchyThemeReload`** runs the apply step on demand.

Because steps 4 and 5 run real `:colorscheme` commands, `ColorScheme` fires
normally, and plugins that listen for it (lualine's `auto` theme, bufferline,
snacks) refresh themselves. The exact behaviour of `Plugin.load()` and
`Loader.reload()` is checked against the pinned nixpkgs lazy.nvim as the
first plan step.

### 3. The generated `omarchy` colorscheme

`colors/omarchy.lua` loads the runtime `neovim-theme.lua` and:

- returns silently if the runtime file is missing;
- clears `vim.g.colors_name`, sets `vim.o.background` from the new `mode`
  field, runs `highlight clear`, then sets `vim.g.colors_name = "omarchy"`;
- applies the existing 35 `highlights`;
- links the standard Treesitter captures (`@comment`, `@string`,
  `@function`, `@keyword`, `@type`, `@constant`, `@variable`, `@punctuation`
  and their common sub-captures) and `@lsp.type.*` groups to those base
  groups, and sets `FloatBorder`, `DiagnosticVirtualText*`,
  `DiagnosticUnderline*`, `DiffAdd/Change/Delete` and `GitSigns*`.

Links are emitted by the renderer as `{ link = "Function" }` entries, so the
fallback stays data-driven from `pkgs/hyprchroma-editors`.

### 4. Renderer changes (`pkgs/hyprchroma-editors`)

- `render_neovim` receives `mode` and emits `mode = "dark"|"light"` next to
  `colors` and `highlights`. The `{ colors, highlights }` table is kept;
  fields are only added.
- Adds the link and extra groups from section 3 to the Neovim output.
- `render_vim` emits a proper colorscheme order: `unlet! g:colors_name`,
  `set background=…`, `highlight clear`, `if exists('syntax_on') | syntax reset | endif`,
  `let g:colors_name = 'omarchy'`, then the groups, adding `VertSplit` and
  `DiffAdd/Change/Delete/Text` with explicit foreground and background. `set termguicolors` is
  emitted only under `if has('termguicolors') && $COLORTERM =~# 'truecolor\|24bit'`.
- Output file paths and `editors.json` are unchanged.

### 5. Vim bridge

- Installed at the existing `.vim/pack/nixarchy/start/nixarchy-theme/`
  (Vim keeps `~/.vim` on `packpath`), plus `colors/omarchy.vim`, which sources
  the runtime `vim-theme.vim`.
- The runtime path honours `$XDG_CONFIG_HOME`.
- The `ColorScheme` autocmd is removed. At startup it runs
  `colorscheme omarchy` only under the startup rule in decision 1. On a
  change it always runs `silent! colorscheme omarchy`, deferred while in
  command-line mode. `colors/omarchy.vim` is a no-op when the runtime file is
  missing.
- Change detection reads the file (`readfile`, about 1.5 KB) on every
  500 ms tick and compares contents, because `getftime` has one-second
  resolution and would hide a second write in the same second. The first
  load records the baseline; a failed apply stays pending.
- Without `timer_start`: startup and `:OmarchyThemeReload` only, as in #53.

### 6. Documentation

`docs/target-matrix.md` gets Neovim and Vim rows (runtime owner, live action,
fallback), and `README.md` explains startup precedence, the `omarchy`
fallback, the best-effort NixVim/nvf status, and the one restart needed after
first deploy.

## Alternatives rejected

- **Install into `~/.config/nvim/{plugin,colors}`** (suggested by both
  reviewers): lazy.nvim keeps it too, but it writes into a user-owned or
  Home Manager-generated tree and collides with whole-directory `nvim`
  symlinks. The data-dir `site/` path loads the same way without that.
- **Keep the 35-group overlay and only fix the load path:** loads under
  LazyVim but overwrites the real colorscheme after every `:colorscheme` and
  leaves Treesitter, LSP and plugin colours stale.
- **Call the theme plugin's `setup()` directly instead of lazy.nvim's
  loader:** also worked in the spike, but needs the plugin's Lua module name,
  which differs from its repository name (`rose-pine/neovim`,
  `catppuccin/nvim`). lazy.nvim already knows how to reload a plugin.
- **Neovim RPC from the hook to `$XDG_RUNTIME_DIR/nvim.*` sockets:** still
  rejected as in #53. It adds socket discovery and trust concerns, and a
  watcher inside each editor already reaches every session.
- **`vim.uv.new_fs_event` instead of a timer:** the renderer replaces the
  file, which can drop an inode watch; a 500 ms `fs_stat` poll is simpler,
  already in use and meets the 2-second target.
- **Ship all 15 Omarchy colorscheme plugins:** out of scope (open question 2
  default); adds a large closure to the ISO.

## Risks

- **lazy.nvim internals.** `Plugin.load()`, `Config.plugins` and
  `Loader.reload` are not a documented API. If a lazy.nvim update changes
  them, step 3 fails inside `pcall` and steps 4–5 still apply a theme. The
  test uses the nixpkgs lazy.nvim so a break shows up in `nix flake check`.
- **Specs that configure a theme in `config`/`init` functions** rather than
  `opts` rely on `Loader.reload` re-running them; if not, step 4 shows that
  plugin's previous colours until restart.
- **Hook latency.** The editor renderer runs last in the hook; with a
  500 ms poll the 2-second target leaves about 1.5 s for earlier targets.
  The Razer check measures it.
  Acceptance checks one same-plugin switch (aether → aether) and one
  cross-plugin switch on Razer.
- **Plugins that cache colours** outside `ColorScheme` handling stay stale;
  the intent puts those out of scope beyond the statusline.
- **Startup rule:** a user with a startup colorscheme sees that colorscheme
  until the first live switch, by design (question 1).
- **Vim TTY:** truecolor-less terminals keep cterm defaults because no
  `cterm` colours are emitted; same as today.
- Hosts: only the owner's host (Razer) builds and runs the runtime check.

## Verification

- `nix flake check` passes, with the module checks updated for the new
  `xdg.dataFile` paths, in both Stylix modes.
- `tests/editors-runtime.sh`, using the shipped bridge files, with
  `pkgs.vimPlugins.lazy-nvim` added to the check's inputs and lazy.nvim set
  up offline (`install.missing = false`, `rocks.enabled = false`,
  `checker.enabled = false`, `change_detection.enabled = false`):
  - **LazyVim load:** isolated XDG dirs, default `reset_packpath` and
    `rtp.reset`, a local `dir=` mock colorscheme plugin whose colours come
    from its `opts`, and a mock Omarchy `neovim.lua` linked from
    `lua/plugins/theme.lua`; asserts `:OmarchyThemeReload` exists.
  - **Same plugin, new options:** in one headless session, change only the
    mock plugin's `opts` in `neovim.lua`, re-run the renderer, and within
    `vim.wait(2000)` assert `Normal.bg` changed without calling the command.
  - **Cross-plugin and mode:** switch to a second mock plugin with the other
    light/dark mode; assert `g:colors_name` and `vim.o.background`.
  - **Palette-only change:** change only the palette with `neovim.lua`
    untouched; assert `g:colors_name == "omarchy"` and the new `Normal.bg`.
  - **Fallback:** `neovim.lua` naming a missing plugin, and no `neovim.lua`
    at all: assert `g:colors_name == "omarchy"`, `@function` resolves (via
    `nvim_get_hl(0, {name = "@function", link = false})`) to the palette
    blue, and `:messages` holds no errors.
  - **Failure recovery:** make the runtime file unreadable for one tick,
    then readable again without changing it; assert the apply completes.
  - **Manual pick kept:** after `:colorscheme default`, an identical
    renderer run (font-only) leaves `g:colors_name == "default"`.
  - **Startup precedence:** a config that sets a colorscheme, and one that
    sets `Normal` highlights only, keep theirs at startup; an empty config
    gets the desktop theme.
  - **Plain Neovim:** the same live switch without lazy.nvim, bridge loaded
    from `site/plugin`.
  - **Vim:** `vim -Nu DEFAULTS` with `COLORTERM=truecolor` and the installed
    pack: startup applies `omarchy` when unset; a renderer run during a
    `:sleep 2` reaches the session through the timer, including two writes in
    the same second; `:OmarchyThemeReload` still works.
  - The existing renderer fixture and idempotence assertions stay.
- Module evaluation fixtures: the new `xdg.dataFile` paths exist, the old
  `pack/` path is gone, and a fixture with Home Manager `programs.neovim`
  enabled evaluates without file collisions.
- **Razer runtime check (owner's host):** with a running LazyVim, switch
  aether → another aether theme, then → a tokyonight theme (installed), then
  → a kanagawa theme (not installed, expect `omarchy`), each within 2 seconds
  and without a restart; Vim follows the same switches.
- The desktop, terminal, shell, Electron, browser and plugin checks stay
  green.
