---
status: draft
issue: 60
intent: intent/2026-11-17-60-starship-rerender.md
---

# Spec: A Home Manager starship change reaches the prompt at the next switch

## Design

Four small changes, all in this repo's own files.

### 1. Copy, then render, at activation (`modules/nixos.nix:402-419`)

`home.activation.nixarchyThemeEngineShell` becomes
`lib.mkIf shellTargetsEnabled { ... }` (`modules/nixos.nix:62`): with every
shell target off it no longer copies anything (intent constraint 3). Its
body:

```sh
runtime_dir="$HOME/.config/omarchy/runtime"
starship_config="$HOME/.config/starship.toml"
starship_base="$runtime_dir/starship.base.toml"
run ${pkgs.coreutils}/bin/mkdir -p "$runtime_dir"
if [ -f "$starship_config" ]; then
  run ${pkgs.coreutils}/bin/install -Dm644 "$starship_config" "$starship_base"
else
  run ${pkgs.coreutils}/bin/rm -f -- "$starship_base"
fi
if [[ ! -v DRY_RUN ]] \
  && ${cfg.package}/lib/hyprchroma/hyprchroma-palette --all >/dev/null 2>&1; then
  ${cfg.package}/bin/hyprchroma shell >/dev/null \
    || echo "nixarchy-omatheme: prompt render failed; it runs again at the next theme change" >&2
fi
```

- `[ -f ]` and `install` follow symlinks, so the Home Manager link and a
  hand-written file take the same branch, and the `readlink -f` that can
  fail under `set -e` on a dangling link is gone.
- **Source gone** (removed, or a dangling link): the base is removed and
  the renderer falls back to `format = "$character"`
  (`pkgs/hyprchroma-shell:54-64`). Owner decision 1.
- **Palette check:** a home with no theme yet stays untouched;
  `hyprchroma-shell` otherwise writes `shell.json` as "unavailable" and
  exits 1 (`pkgs/hyprchroma-shell:151-154`).
- **Dry run:** the render and the probe are skipped outright, rather than
  wrapped in `run` (which prints the command; redirecting it would hide
  that output).
- **Failure:** a failed render warns and does not fail the switch.
- **Order:** the entry's `before` gains `"reloadSystemd"`. If the switch
  restarts `hyprchromad`, its `ExecStartPre` render then reads the new base
  too, so whichever render finishes last writes the same result.

`hyprchroma shell` is what the unit's `ExecStartPre` runs (line 500): same
renderer, palette and output. `NIXARCHY_THEME_ENGINE_MODE`, the one
environment difference, is read by nothing in the package (`grep` over
`$out/bin` and `$out/lib/hyprchroma`: no match).

### 2. Honour `targets.starship = false` (`modules/nixos.nix:211-215`, `312-356`)

Today the option does nothing: `shell-theme.sh` and `shell-theme.fish`
always export `STARSHIP_CONFIG` pointing at the rendered file, and the Bash,
Zsh and Fish hooks source them. When `targets.starship` is false, each hook
keeps the shell's own `STARSHIP_CONFIG` across the source:

```sh
# Bash and Zsh, inside _hyprchroma_shell_refresh, around the source:
local starship_set=''${STARSHIP_CONFIG+x} starship_saved=''${STARSHIP_CONFIG-}
. "$file"
if [ -n "$starship_set" ]; then STARSHIP_CONFIG=$starship_saved; else unset STARSHIP_CONFIG; fi
```

```fish
# Fish
set -l starship_saved $STARSHIP_CONFIG
set -q STARSHIP_CONFIG; and set -l starship_set 1
source "$file"
if set -q starship_set; set -gx STARSHIP_CONFIG $starship_saved; else; set -e STARSHIP_CONFIG; end
```

Starship then reads the user's own config, unthemed. The renderer still
writes `runtime/starship.toml`; nothing points at it. With the option true
(the default) the hooks are unchanged.

Known limit, not changed here: with `targets.starship` true and every shell
target off, no hook sources the theme file, so the prompt is not themed.
The option description says so.

### 3. Find a Home Manager starship (`pkgs/hyprchroma-shell:68`)

`render_starship` returns `None` when `shutil.which("starship")` finds
nothing on the trusted path, which has `/run/current-system/sw/bin` but no
per-user profile (`pkgs/hyprchroma.nix:24-25`). Only that lookup changes:

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

Empty entries are dropped so the lookup never probes the working directory.
The renderer never runs starship; it only decides whether to write the
prompt file. So this is not a trust decision, and the trusted `PATH` the
rest of `hyprchroma` uses stays as it is. The status line (line 143) keeps
reading the render result.

### 4. Tests

- `tests/runtime-targets.sh` (real renderer):
  - no `starship` on `PATH`, one at `$HOME/.nix-profile/bin/starship` →
    `starship.toml` written (the real lookup path; no test-only variable);
  - base changed after a render → the new content replaces the stale file;
  - base removed → `runtime/starship.toml` holds `format = "$character"`.
- `tests/shell-activation.sh`, new, registered in `flake.nix` like
  `runtime-targets`. It takes the generated activation `data` of a test
  system whose `programs.nixarchyThemeEngine.package` is a stub derivation
  (stub `bin/hyprchroma` and `lib/hyprchroma/hyprchroma-palette` that log
  their calls), and runs it under `set -eu` with Home Manager's `run`
  helper in a temporary home:
  1. `~/.config/starship.toml` a symlink to a new config → base copied,
     render called once, after the copy;
  2. source removed, and a dangling link → base removed, render called,
     exit 0;
  3. palette fails → no render, no `shell.json`, exit 0;
  4. render fails → warning on stderr, exit 0;
  5. `DRY_RUN=1` → nothing written, neither stub called.
  It also sources the generated Bash hook of a system with
  `targets.starship = false`: a preset `STARSHIP_CONFIG` survives, an unset
  one stays unset; with the default, it points at the runtime file.
- `flake.nix` module-eval checks: the shell entry's `before` contains
  `reloadSystemd`; a system with every shell target off has no
  `nixarchyThemeEngineShell` entry.

## Alternatives rejected

- **`hyprchromad` watches `starship.base.toml`.** A new watcher for a file
  written only at activation; needs the session, and the daemon loop is
  upstream code.
- **Add `starship.base.toml` to the sync fingerprint** (upstream
  `bin/hyprchroma:970-981`). A switch triggers no sync, so it fixes nothing
  on its own.
- **Restart `hyprchromad` from activation.** Re-syncs every framework for a
  prompt change and needs a running session.
- **Add the per-user profile to the trusted path.** Widens what every
  helper may execute, for a lookup that executes nothing.
- **Tell the renderer about `targets.starship`** (an environment variable
  or a flag file) so it skips `starship.toml`. Renders run from the unit,
  the theme hook's sync and the user's terminal; only the unit would get
  the variable. The hook is the one place every shell passes through.

## Risks

- **Render cost per switch:** one Python run, about 0.1 s; measured on p620.
- **Open shells re-source the theme file** because its mtime changes,
  even with the same content. Cheap; the same as after any theme change.
- **Headless switch** (p510, CI VM): with a palette the render writes only
  under the user's home and uses no session bus; without one, case 3.
- **Two renders at once** (activation and a restarted daemon): both write
  by atomic rename and read the same base after the reorder; the last
  write has the same content.
- **The `if [ -f ]` rewrite** changes the existing copy code: covered by
  cases 1 and 2.

## Verification

- `nix flake check` in the worktree.
- Break proofs, each turning a check red, then restored: drop
  `reloadSystemd` from `before`; drop the palette check; drop the `rm -f`
  branch; drop the `|| echo` fallback; drop the `.nix-profile` path;
  drop the save/restore in the Bash hook; drop the `mkIf shellTargetsEnabled`.
- The `/etc/profiles/per-user` path cannot be built in the sandbox. On
  p620, run the built `lib/hyprchroma/hyprchroma-shell` with a `PATH` that
  holds only coreutils and with `XDG_CONFIG_HOME`/`XDG_STATE_HOME` set to a
  temporary directory holding a copy of the runtime base, and check that
  `starship.toml` is written there.
- p620 after deploy: add `[status] disabled = false` to the starship
  settings on a scratch branch, switch, and check a new terminal and the
  runtime file without logging out; revert and switch again; read the
  entry's time from the journal.
- razer and p510 take it with their next deploy (p510 with the owner's OK).
