---
status: draft
issue: 60
spec: spec/2026-11-17-60-starship-rerender.md
coders:
  1: codex   # small, tricky shell under Home Manager's set -eu, run and DRY_RUN
  2: codex   # small, tricky: save/restore of a variable around source in three shells
  3: coder   # a ten-line Python function
  4: coder   # tests in the repo's existing style: a shell test, flake wiring, eval asserts
  5: coder   # documentation
reviewers:
  - codex    # found the per-target, test-seam and fallback-coverage gaps in the spec
  - agy      # found the missing-trigger cause, the symlink and dry-run issues; second read
---

# Plan: A Home Manager starship change reaches the prompt at the next switch

Worktree: `/mnt/data/vmtest/omatheme-60`, branch `fix/60-starship-rerender`.

## Approved decisions (from intent and spec)

1. A switch that changes the starship config re-renders
   `~/.config/omarchy/runtime/starship.toml` at activation, after the copy
   to `starship.base.toml`, when a palette exists. No palette, no writes.
   A failed render warns and does not fail the switch. Dry run: no render,
   no palette probe.
2. The copy follows symlinks (`[ -f ]`, `install`); when
   `~/.config/starship.toml` is missing or a dangling link, the base is
   removed and the prompt falls back to `format = "$character"` (owner
   decision 1). Hand edits without a switch are out of scope (decision 2).
3. The shell entry runs only when `shellTargetsEnabled`, and before
   `reloadSystemd`.
4. `targets.starship = false` is honoured in the Bash, Zsh and Fish hooks:
   they keep the shell's own `STARSHIP_CONFIG` across sourcing the theme
   file. The renderer is not told about the option.
5. The renderer finds starship also in `/etc/profiles/per-user/<user>/bin`
   and `~/.nix-profile/bin`, dropping empty `PATH` entries; it only checks
   existence. The trusted `PATH` is unchanged.
6. **Deviation D1 (plan review):** the renderer refuses any symlinked
   `~/.config/starship.toml` when the base is missing
   (`pkgs/hyprchroma-shell:59-61`), so after decision 2 removes the base
   for a dangling link the prompt would stay stale. The renderer treats a
   *dangling* source link like a missing file (default prompt); a live
   link is still refused, so it never reads through one.
7. Rejected: a daemon watcher, the sync fingerprint, restarting the unit,
   widening the trusted path, a renderer flag for `targets.starship`.

## Steps

1. **Shell activation** — `modules/nixos.nix:402-419`
   (`home.activation.nixarchyThemeEngineShell`).
   - Wrap the attrset in `lib.mkIf shellTargetsEnabled` (defined at
     line 62).
   - `before = [ "reloadSystemd" ];` (keep `after = [ "linkGeneration" ]`).
   - Replace the body with the spec's section 1 block exactly: `mkdir -p`;
     `if [ -f "$starship_config" ]` → `run install -Dm644`, `else`
     `run rm -f --`; then
     `if [[ ! -v DRY_RUN ]] && ${cfg.package}/lib/hyprchroma/hyprchroma-palette --all >/dev/null 2>&1; then ${cfg.package}/bin/hyprchroma shell >/dev/null || echo "nixarchy-omatheme: prompt render failed; it runs again at the next theme change" >&2; fi`.
     Use `${pkgs.coreutils}/bin/...` for `mkdir`, `install`, `rm` as the
     file does elsewhere (lines 378, 394).
   - Check: `git add -A && nix eval .#checks.x86_64-linux.module.drvPath`
     and `nix build .#checks.x86_64-linux.runtime`.
   - Traps: the flake sees only staged files; `''${` escapes `${` inside
     Nix `''` strings; HM activation runs under `set -eu`, so every
     command that may fail sits in an `if` or before `||`.

2. **`targets.starship` in the hooks** — `modules/nixos.nix:312-356`
   (`programs.bash.bashrcExtra`, `programs.zsh.initContent`,
   `programs.fish.interactiveShellInit`) and the option description at
   211-215.
   - **Before editing**, save the three hook strings of the default test
     system (`nix eval --raw` of `programs.bash.bashrcExtra`,
     `programs.zsh.initContent`, `programs.fish.interactiveShellInit`
     for `home-manager.users.test` of the module check's no-Stylix
     system) to files under `/mnt/data/vmtest/omatheme-60-baseline/`.
   - When `cfg.targets.starship` is false, the `source`/`.` line inside
     `_hyprchroma_shell_refresh` becomes, for Bash and Zsh (Nix-escaped):

     ```sh
     local starship_set=''${STARSHIP_CONFIG+x} starship_saved=''${STARSHIP_CONFIG-}
     . "$file"
     if [ -n "$starship_set" ]; then STARSHIP_CONFIG=$starship_saved; else unset STARSHIP_CONFIG; fi
     ```

     (Zsh keeps `source "$file"` in place of `. "$file"`), and for Fish:

     ```fish
     set -l starship_saved $STARSHIP_CONFIG
     set -q STARSHIP_CONFIG; and set -l starship_set 1
     source "$file"
     if set -q starship_set; set -gx STARSHIP_CONFIG $starship_saved; else; set -e STARSHIP_CONFIG; end
     ```

     Generate it with
     `lib.optionalString` or an `if` in Nix so that with the option true
     the hook text is byte-for-byte as today.
   - Option description: "Point Starship at the themed runtime config.
     Needs a shell target (bash, zsh or fish) to load it. When false,
     shells keep their own STARSHIP_CONFIG."
   - Check: `nix eval` the three hook strings again; the default system's
     must be byte-for-byte the saved baseline (`cmp`); the
     `targets.starship = false` system's must contain the snippets.
   - Traps: Zsh's `local` and Bash's `local` both accept
     `local a=${X+x} b=${X-}`; Fish has no `local`, use `set -l`.

3. **Starship lookup** — `pkgs/hyprchroma-shell:68` (`render_starship`).
   - Add `import pwd` and:

     ```python
     def starship_installed() -> bool:
         paths = os.environ.get("PATH", "").split(os.pathsep)
         try:
             paths.append(f"/etc/profiles/per-user/{pwd.getpwuid(os.getuid()).pw_name}/bin")
         except KeyError:
             pass
         paths.append(str(Path.home() / ".nix-profile/bin"))
         return shutil.which("starship", path=os.pathsep.join(p for p in paths if p)) is not None
     ```

     `render_starship` calls it instead of `shutil.which("starship")`.
     Line 143's status stays as is.
   - D1, in `starship_base` (lines 54-64): `if source.is_symlink(): return
     None` becomes `if source.is_symlink(): return None if source.exists()
     else DEFAULT` with `DEFAULT = 'format = "$character"\n'` shared with
     the last line.
   - Check: `nix build .#checks.x86_64-linux.runtime`.
   - Traps: none beyond keeping the file's exception list (line 151)
     unchanged; `KeyError` is handled inside the function.

4. **Tests.**
   - `tests/runtime-targets.sh` (after line 149): three cases with the
     real renderer: no `starship` in `$bin`, a stub at
     `$home/.nix-profile/bin/starship` → `starship.toml` written; a
     changed base after a render → new content in `starship.toml`; base
     removed → `starship.toml` contains `format = "$character"`; base
     removed and `$config/starship.toml` a dangling link → the same
     (D1); base removed and `$config/starship.toml` a live link → no
     `starship.toml` written (still refused). The
     first case must take `starship` off the `PATH` the script uses for
     the renderer (the current stubs at lines 31-35 put it on).
   - `tests/shell-activation.sh`, new. Inputs from `flake.nix` as env
     vars: `SHELL_ACTIVATION` (a file with the generated `data` of a
     system whose `programs.nixarchyThemeEngine.package` is a stub
     package), `BASH_HOOK_OFF` and `BASH_HOOK_ON` (the generated
     `bashrcExtra` with `targets.starship` false and default). The stub
     package (`pkgs.runCommand` in `flake.nix`) has `bin/hyprchroma`
     and `lib/hyprchroma/hyprchroma-palette`, each appending its name to
     `$STUB_LOG` and exiting with `$STUB_RENDER_RC` / `$STUB_PALETTE_RC`
     (default 0). The script defines Home Manager's
     `run() { if [[ -v DRY_RUN ]]; then echo "$@"; else "$@"; fi; }`,
     `export -f run`s it, and runs the data with `bash -eu` in a fresh
     `HOME` per case, each asserting exit 0:
     1. `~/.config/starship.toml` a symlink to a new config → base holds
        its content, log `palette` then `hyprchroma shell`;
     2. source removed, and separately a dangling link → base absent,
        render logged;
     3. `STUB_PALETTE_RC=1` → no render in the log, no
        `~/.local/state/hyprchroma/shell.json`;
     4. `STUB_RENDER_RC=1` → the warning on stderr;
     5. `DRY_RUN=1` → no base, empty log.
     Case 1 asserts the log order by checking the base exists when the
     stub renderer runs (the stub records `test -f` of the base). Hook
     cases: source each hook, write a `shell-theme.sh` exporting
     `STARSHIP_CONFIG=/runtime`, call `_hyprchroma_shell_refresh`, and
     assert: off + preset `/mine` → `/mine`; off + unset → unset;
     on → `/runtime`.
   - `flake.nix`: a `shellActivationTest` `runCommand` next to
     `runtimeTargetsTest` (line 166), registered as `shell-activation`
     beside `runtime` (line 282); new test systems via `makeTestSystem`
     (stub package; `targets.starship = false`; every shell target
     false). In the `module` check (line 287 onwards) add asserts: the
     shell entry's `before` has `reloadSystemd`; the all-off system has
     no `nixarchyThemeEngineShell` in `home.activation`.
   - Check: `git add -A && nix flake check`.
   - Traps: `runCommand` has no network; use `pkgs.bash`/`coreutils`
     only; `home.activation.<name>` of a `mkIf false` entry is absent,
     test with `builtins.hasAttr`.

5. **Docs** — `docs/target-matrix.md:18` (Starship row): "re-rendered at
   every switch; `targets.starship = false` leaves the shell's own
   config"; README's target list if it describes Starship (check with
   `grep -n -i starship README.md`).
   - Check (every step): `nix fmt -- --ci` (the formatter is
     `nixfmt-tree`, i.e. treefmt) passes.

6. **Lead: proofs and host check** (not handed off).
   - Break proofs run only on a committed implementation (`git status`
     clean first), so `git checkout HEAD -- <file>` restores the
     implementation, not the pre-change file. Break, see red, restore:
     drop `reloadSystemd`; drop the
     palette check; drop the `rm -f` branch; drop `|| echo`; drop the
     `.nix-profile` path; drop the save/restore in the Bash hook; drop
     the `mkIf shellTargetsEnabled`; drop D1's dangling-link fallback.
     Each must turn `nix flake check` red.
   - On p620: run the built `lib/hyprchroma/hyprchroma-shell` with
     `PATH=<coreutils>/bin`, `XDG_CONFIG_HOME` and `XDG_STATE_HOME` in a
     temporary directory holding a copy of `starship.base.toml` →
     `starship.toml` written (the `/etc/profiles/per-user` path).
   - Deploy p620 after the PR merges (announce on the bus); on a scratch
     branch of the config add `[status] disabled = false` to
     `programs.starship.settings`, switch, check a new terminal and
     `grep status ~/.config/omarchy/runtime/starship.toml`; revert,
     switch, check again; read the entry's time in the journal.

## Tests

`nix flake check` green, including `runtime`, `shell-activation` and
`module`; each break proof in step 6 red then green.

## Rollback

Revert the merge commit; the next switch restores the old activation
entry and hooks. Runtime files are regenerated at the next theme change
or login, as before.
