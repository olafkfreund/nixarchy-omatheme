---
status: approved
issue: 63
spec: spec/2026-11-12-63-editor-live-theme.md
coders:
  1: codex   # small, tricky state machine (timer, pending retry, native/fallback order)
  2: coder   # renderer data changes in one Python file
  3: coder   # module wiring, mechanical but touches Home Manager paths
  4: coder   # flake check inputs and evaluation fixtures
  5: agy     # large test script, many mechanical cases
  6: coder   # documentation rows and README section
reviewers:
  - codex    # reviewed intent and spec; checks the diff against both
  - agy      # independent second read of the bridge logic and tests
---

# Plan: LazyVim, Neovim and Vim follow live desktop theme changes

Branch `fix/63-editor-live-theme`, based on `origin/main`. Steps 7 and 8 stay
with the session (Opus): host check, commits, PR.

## Approved decisions (from the spec)

- **Startup:** the user's config wins. The bridge applies a theme at
  `VimEnter` only when `g:colors_name` is unset **and** `Normal` has no fg or
  bg. Deviation found in step 1: Neovim 0.10+ always gives `Normal` its
  built-in colours (`#e0e2ea`/`#14161b`, swapped for light), so in Neovim
  "no fg or bg" also counts that built-in pair as unset. Vim has no default
  `Normal` colours and keeps the plain check. It always records a baseline (mtime + contents) at startup.
  Deviation found in review: the Vim generated file starts with
  `if !has('gui_running') && !&termguicolors && !(truecolor $COLORTERM) | finish | endif`,
  because it writes only gui colours; without this a Vim under tmux or ssh
  with no `COLORTERM` lost the user's colours on every switch. The module
  check also builds the `programs.neovim` fixture's `home-files`, the only
  place Home Manager reports a target collision.
- **Change = palette content change.** Identical renderer output (same
  theme re-selected, font-only update) does nothing. A palette change
  without an Omarchy `neovim.lua` change uses the `omarchy` fallback.
- **Missing plugin:** palette-derived `omarchy` colorscheme; never install
  or fetch.
- **Declarative Neovim:** HM `programs.neovim` evaluation-checked; NixVim and
  nvf best-effort, documented only.
- **Stylix:** editors follow live switches in both modes.
- **No `ColorScheme` overlay** in either editor. **No RPC.** Nothing written
  under `~/.config/nvim`.
- **Install paths:** Neovim `xdg.dataFile."nvim/site/plugin/nixarchy-theme.lua"`
  and `xdg.dataFile."nvim/site/colors/omarchy.lua"`; Vim
  `.vim/pack/nixarchy/start/nixarchy-theme/{plugin/nixarchy-theme.vim,colors/omarchy.vim}`.
  The old `.local/share/nvim/site/pack/...` entry is removed.
- **Paths read by the bridges:** `($XDG_CONFIG_HOME or ~/.config)/omarchy/runtime/{neovim-theme.lua,vim-theme.vim}`
  and `($XDG_STATE_HOME or ~/.local/state)/omarchy/current/theme/neovim.lua`.

### Neovim apply step (exact order)

1. `vim.g.colors_name = nil`; set `vim.o.background` from runtime `mode`.
2. Native path only if Omarchy `neovim.lua` exists, names a colorscheme in
   the `LazyVim/LazyVim` entry's `opts.colorscheme`, and either its contents
   changed since the last apply (timer-driven updates) or the apply is the
   startup `VimEnter` apply or `:OmarchyThemeReload` (both always try the
   native path). Otherwise go to 5. The startup baseline records the
   contents of both the runtime file and `neovim.lua`.
3. If `package.loaded.lazy`: `require("lazy.core.plugin").load()`; take the
   plugin entries of `neovim.lua` other than `LazyVim/LazyVim`, and find each
   in `require("lazy.core.config").plugins` by its `name`, else by matching
   `plugin[1]` to its slug, else by its slug basename (lazy.nvim's default
   name, e.g. `tokyonight.nvim`), never by the colorscheme name; if `plugin._.installed`,
   `require("lazy.core.loader").reload(plugin)`. Failure → step 4.
4. `vim.cmd.colorscheme(name)`. Failure → step 5.
5. `vim.cmd.colorscheme("omarchy")`.

All calls `pcall`ed and silent. Verified in the scratchpad against lazy.nvim
11.17.5 (the nixpkgs version): with `lua/plugins/theme.lua` symlinked to a
`neovim.lua`, changing its `opts`, then `Plugin.load()` +
`Loader.reload(aether)` + `:colorscheme aether` moved `Normal.bg`
`#0b1b2b` → `#300000`.

### Timer (both editors)

`timer_start(500, …, { ["repeat"] = -1 })` in Lua (`repeat` is reserved;
Vim: `{'repeat': -1}`), on the main loop, never a raw `vim.uv` timer
(`E5560`). Neovim autocmds (`VimEnter`, `VimLeavePre`) live in one
`nvim_create_augroup("nixarchy_theme_bridge", { clear = true })`. Vim creates
its timer only `if exists('*timer_start')`; without timers it applies at
startup (under the startup rule) and on `:OmarchyThemeReload` only. Neovim: `fs_stat` mtime (`sec`, `nsec` compared
separately) gates a content read. Vim: `readfile` and compare contents on
every tick (`getftime` is one-second resolution). Contents are recorded only
after a successful apply; a failure sets `pending`, retried each tick with
no further file change. Apply waits while `mode() == "c"`. Neovim stops the
timer on `VimLeavePre`. Load guard `g:loaded_nixarchy_theme_bridge`.

## Steps

1. **Bridge sources** (codex). Create
   `pkgs/editors/nixarchy-theme.lua`, `pkgs/editors/omarchy.lua`,
   `pkgs/editors/nixarchy-theme.vim`, `pkgs/editors/omarchy.vim`
   implementing the decisions above. `omarchy.lua` / `omarchy.vim`: no-op if
   the runtime file is missing; else clear `colors_name`, set `background`,
   `highlight clear`, set `colors_name = "omarchy"`, apply highlights from
   the runtime table, honouring `{ link = … }` entries. `omarchy.vim` only
   sources the runtime `vim-theme.vim` when readable (that file already
   carries the colorscheme preamble from step 2). The Vim startup "no
   colours" test uses `synIDattr(synIDtrans(hlID('Normal')), 'fg'|'bg', 'gui')`
   and `'cterm'`. `:OmarchyThemeReload` in both.
   In `pkgs/hyprchroma.nix`: add an `editorBridges ? ./editors` argument
   next to `editorRenderer` (line 13) and install the four files with
   `install -Dm644` to `$out/share/hyprchroma/editors/` next to the
   renderer install (line 145).
   → verify: `git add -N pkgs/editors` (the session does this; the flake is
   Git-backed and ignores untracked files), then
   `nix build .#default && ls result/share/hyprchroma/editors`; then with
   isolated `HOME`/`XDG_*` dirs under a temp dir, copy the files to
   `$XDG_DATA_HOME/nvim/site/{plugin,colors}/` and run
   `nvim --headless -c 'lua assert(vim.fn.exists(":OmarchyThemeReload") == 2)' -c 'qa!'`
   with no runtime file present: exit 0, no error output.
   Traps: Lua inside Nix `''` strings is gone, so no `''${` escaping;
   `vim.fn.timer_start` callback receives the timer id; do not use
   `vim.loop`-only APIs without `vim.uv or vim.loop`.

2. **Renderer** (coder). `pkgs/hyprchroma-editors`:
   - `render_neovim(colors, mode)` (line ~97, call at line ~136) emits
     `mode = "dark"|"light"` beside `colors` and `highlights`; keep both
     existing keys.
   - Add Neovim-only entries: links `@comment→Comment`, `@string→String`,
     `@character→Character`, `@number→Number`, `@boolean→Boolean`,
     `@constant→Constant`, `@function→Function`, `@function.call→Function`,
     `@method→Function`, `@keyword→Keyword`, `@conditional→Conditional`,
     `@repeat→Repeat`, `@operator→Operator`, `@type→Type`,
     `@variable→Identifier`, `@property→Identifier`, `@punctuation→Special`,
     `@tag→Statement`, `@lsp.type.function→Function`,
     `@lsp.type.variable→Identifier`, `@lsp.type.type→Type`,
     `@lsp.type.keyword→Keyword`; and colour groups `FloatBorder`,
     `DiagnosticVirtualText{Error,Warn,Info,Hint}`,
     `DiagnosticUnderline{Error,Warn,Info,Hint}` (`sp` + `undercurl`),
     `DiffAdd/DiffChange/DiffDelete/DiffText`, `GitSignsAdd/Change/Delete`.
     Emit every highlight key bracketed, `["@comment"] = { link = "Comment" }`
     and `["Normal"] = { fg = …, bg = … }` (the existing bare-key output at
     line 111 is invalid Lua for `@` and dotted names).
   - `render_vim` (line ~116): order `unlet! g:colors_name`,
     `set background=…`, `highlight clear`,
     `if exists('syntax_on') | syntax reset | endif`,
     `let g:colors_name = 'omarchy'`; replace bare `set termguicolors` with
     `if has('termguicolors') && $COLORTERM =~# 'truecolor\|24bit' | set termguicolors | endif`;
     add `VertSplit` and `DiffAdd/DiffChange/DiffDelete/DiffText` with
     explicit `guifg`/`guibg`.
   - Output paths and `editors.json` unchanged.
   → verify: run the renderer against the fixture palette from
   `tests/editors-runtime.sh` in a temp `XDG_CONFIG_HOME`, then
   `nvim --headless -u NONE -c "lua local t=dofile('…/neovim-theme.lua'); assert(t.mode=='light'); assert(t.highlights['@function'].link=='Function')" -c 'qa!'`
   and `vim -Nu NONE -es -c 'source …/vim-theme.vim' -c 'if g:colors_name !=# "omarchy" | cquit | endif' -c 'qa!'`;
   two runs byte-identical.
   Traps: Diff colours need contrast: background from the hue, foreground
   `background` colour; `undercurl` is Neovim-only.

3. **Module wiring** (coder). `modules/nixos.nix`:
   - Delete `neovimThemeBridge` and `vimThemeBridge` (lines 61–123; line 124
     starts an unrelated comment that stays).
   - Replace the Neovim `home.file` entry (lines ~339–342) with
     `xdg.dataFile."nvim/site/plugin/nixarchy-theme.lua".source` and
     `xdg.dataFile."nvim/site/colors/omarchy.lua".source`, from
     `"${cfg.package}/share/hyprchroma/editors/…"`, under
     `lib.mkIf cfg.targets.neovim`.
   - Vim entry (lines ~343–347): source from the package, and add
     `.vim/pack/nixarchy/start/nixarchy-theme/colors/omarchy.vim`.
   - Update the `targets.neovim` description (line 291) to mention the
     startup rule.
   → verify: `nix-instantiate --parse modules/nixos.nix >/dev/null`, and
   `nix eval --json .#checks.x86_64-linux.editors.drvPath` still evaluates.
   The module asserts are expected to fail on the removed `pack/` path until
   step 4 updates them; steps 3 and 4 are verified together by
   `nix build .#checks.x86_64-linux.module`.
   Traps: `xdg.dataFile` lives in the HM user config, not `home.file`; keep
   the existing `lib.optionalAttrs` style for `home.file` and do not merge
   the attrsets wrongly; `cfg.package` must be the built hyprchroma.

4. **Flake checks** (coder). `flake.nix`:
   - `editorRuntimeTest` (line 171): add `pkgs.vimPlugins.lazy-nvim`,
     `pkgs.gnused` and `pkgs.util-linux` (for `script`, the Vim timer
     fallback) to `nativeBuildInputs`, export
     `LAZY_NVIM=${pkgs.vimPlugins.lazy-nvim}` to the script.
   - Module asserts (lines ~310–314): for each of `noStylixSystem`,
     `stylixSystem` and `runtimeSystem`, assert
     `config.home-manager.users.test.xdg.dataFile` has
     `nvim/site/plugin/nixarchy-theme.lua` and `nvim/site/colors/omarchy.lua`,
     `home.file` no longer has the old `pack/` path, and has the Vim
     `plugin/` and `colors/` entries.
   - New fixture `neovimProgramSystem = makeTestSystem [ { home-manager.users.test.programs.neovim.enable = true; } ];`
     and force evaluation of its `home-manager.users.test.home.file` and
     `xdg.dataFile` (collision = eval error).
   → verify: `nix flake check -L`.
   Traps: `checks` must stay offline; no `fetchFromGitHub` for test plugins.

5. **Runtime tests** (agy). Rewrite `tests/editors-runtime.sh`, keeping the
   existing renderer fixture and idempotence checks, and add the cases
   below, all against `$HYPRCHROMA_PACKAGE/share/hyprchroma/editors/*`
   installed into an isolated `$HOME`/XDG tree:
   - **LazyVim load:** `init.lua` prepends `$LAZY_NVIM`, `lazy.setup` with
     `{ import = "plugins" }`, `install.missing = false`,
     `rocks.enabled = false`, `checker.enabled = false`,
     `change_detection.enabled = false`, default performance resets. A local
     mock colorscheme plugin (`dir = …`, slug `mock/mocktheme.nvim` with no
     `name`, so lookup by basename is exercised; `lua/mocktheme/init.lua`
     with `setup(opts)` storing `opts.bg`, and `colors/mocktheme.lua` using
     it) and a mock Omarchy `neovim.lua` symlinked from
     `lua/plugins/theme.lua`. Assert `:OmarchyThemeReload` exists.
   - **Same plugin, new opts:** one headless session; rewrite `neovim.lua`
     with new `opts.bg`, run the renderer with a second palette via
     `vim.fn.system`, `vim.wait(2000, …)`; assert `Normal.bg`.
   - **Cross-plugin and mode:** second mock plugin, opposite mode; assert
     `g:colors_name` and `vim.o.background`.
   - **Palette-only:** renderer with a third palette, `neovim.lua`
     untouched; assert `g:colors_name == "omarchy"` and the new bg.
   - **Fallback:** `neovim.lua` naming a missing plugin; and no
     `neovim.lua`; assert `omarchy`, `nvim_get_hl(0, {name="@function", link=false}).fg`
     equals palette blue, `:messages` has no `E\d+`.
   - **Failure recovery:** run the renderer with a new palette, immediately
     `chmod 000` the runtime file for at least one tick, then restore the
     mode without rewriting; assert the new palette is applied.
   - **Manual pick kept:** `:colorscheme default`, rerun renderer with the
     same palette; assert still `default`.
   - **Startup precedence:** config with `vim.cmd.colorscheme("default")`,
     config with only `nvim_set_hl(0, "Normal", …)`, empty config.
   - **Plain Neovim:** no lazy.nvim, bridge from `site/plugin`; live switch.
   - **Vim:** `COLORTERM=truecolor TERM=xterm-256color script -qec "vim -X -u $T/vimrc -i NONE -n -c 'autocmd VimEnter * ++once source $T/t.vim'" /dev/null`
     with `vimrc` containing only `set nocompatible` and the pack under
     `$HOME/.vim/pack/...` (verified in step 1: `-u NONE`/`-u DEFAULTS`
     skip plugins, `-es` skips them too, and without a pty Vim exits on
     stdin EOF before `VimEnter`; results are written to a file with
     `writefile`); startup applies `omarchy`; renderer run during
     `sleep 2` updates via timer, including two writes within one second;
     `:OmarchyThemeReload` works.
   → verify: `nix build .#checks.x86_64-linux.editors -L`.
   Traps: `-c` commands run before `VimEnter`, so startup assertions go in
   `-c "autocmd VimEnter * ++once lua …"` or after `vim.wait`; the failure
   case stages the new runtime file at mode `000` in the same directory and
   `mv -f`s it into place (a plain `chmod` does not move `mtime`), waits one
   tick, then `chmod 644` and waits again. Vim timers may not fire in `-es` mode; if they do not, run Vim
   with `--not-a-term` under `script -qc` or `-X` and record the choice in
   this plan; `chmod 000` has no effect as root in some sandboxes, so skip
   that case with a message when `id -u` is 0; every editor run needs
   `timeout`.

6. **Docs** (coder). `docs/target-matrix.md`: add Neovim and Vim rows
   (structure owner: user config / Home Manager; runtime owner: hyprchroma
   runtime files; runtime action: in-editor watcher re-applies the theme's
   colorscheme or `omarchy`; fallback: `:OmarchyThemeReload` / restart).
   `README.md`: short "Editors" section: startup rule, `omarchy` fallback,
   palette-only behaviour, NixVim/nvf best-effort, one restart after first
   deploy.
   → verify: `nix flake check` (any docs check) and read-through.

7. **Host check on Razer** (session, needs the owner's OK before switching).
   Build and switch the owner's config with this branch as the input, then
   in a running LazyVim: aether → another aether theme, → a tokyonight
   theme, → a kanagawa theme (expect `omarchy`); Vim the same; time each
   switch (≤ 2 s); check lualine follows.
   → record results in the PR.

8. **PR** (session). Push the branch, open a PR linking intent, spec and
   plan, listing which steps each implementer did and any deviations.

## Tests

```bash
nix build .#default
nix build .#checks.x86_64-linux.editors -L
nix flake check -L
```

All pass; the editors check fails if the bridge does not load under
lazy.nvim defaults or a live change does not reach the editor.

## Rollback

Revert the branch's implementation commits. Home Manager removes the new
`site/plugin` and `colors` links and restores the previous bridge on the next
switch; generated runtime files are rewritten by the old renderer on the
next theme change. No user files are touched, so nothing else needs undoing.
