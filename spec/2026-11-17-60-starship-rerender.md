---
status: draft
issue: 60
intent: intent/2026-11-17-60-starship-rerender.md
---

# Spec: A Home Manager starship change reaches the prompt at the next switch

## Design

Three changes, all small.

### 1. Render at activation, after the copy (`modules/nixos.nix:402-419`)

`home.activation.nixarchyThemeEngineShell` keeps copying
`~/.config/starship.toml` to `runtime/starship.base.toml`, and then:

- **Source gone:** when `~/.config/starship.toml` neither is a symlink nor
  a regular file, remove `starship.base.toml` (`run rm -f`). The renderer
  then falls back to `format = "$character"` (`pkgs/hyprchroma-shell:54-64`).
  Owner decision 1.
- **Render:** only when `shellTargetsEnabled` (`modules/nixos.nix:62`, the
  same gate as the unit's `ExecStartPre`, line 500), and only when a palette
  exists:

  ```sh
  if ${cfg.package}/lib/hyprchroma/hyprchroma-palette --all >/dev/null 2>&1; then
    run ${cfg.package}/bin/hyprchroma shell >/dev/null \
      || echo "nixarchy-omatheme: prompt render failed; it runs again at the next theme change" >&2
  fi
  ```

  The palette check keeps a home with no theme yet untouched:
  `hyprchroma-shell` otherwise writes `shell.json` as "unavailable" and exits
  1 (`pkgs/hyprchroma-shell:151-154`). A render failure warns and does not
  fail the switch (HM activation runs under `set -e`). `run` gives the dry
  run.
- **Order:** add `"reloadSystemd"` to the entry's `before`. If the switch
  restarts `hyprchromad`, its `ExecStartPre` render then reads the new base
  too, so whichever render finishes last writes the same result. Today
  `before = [ ]` leaves it to chance (intent, problem 2).

`hyprchroma shell` is the command the daemon's `ExecStartPre` runs: same
renderer, same palette, same output. `NIXARCHY_THEME_ENGINE_MODE`, the one
environment difference, is read by nothing in the package
(`grep` over `$out/bin` and `$out/lib/hyprchroma`: no match); the module
applies the mode elsewhere, so the activation render needs no extra
environment.

### 2. Find a Home Manager starship (`pkgs/hyprchroma-shell:68`)

`render_starship` returns `None` when `shutil.which("starship")` finds
nothing on the trusted path, which has `/run/current-system/sw/bin` but no
per-user profile (`pkgs/hyprchroma.nix:24-25`). Extend only this lookup:

```python
def starship_installed() -> bool:
    user = pwd.getpwuid(os.getuid()).pw_name
    extra = [f"/etc/profiles/per-user/{user}/bin", str(Path.home() / ".nix-profile/bin")]
    return shutil.which("starship", path=os.pathsep.join([os.environ.get("PATH", ""), *extra])) is not None
```

The renderer never runs starship; it only decides whether to write the
prompt file. So the lookup is not a trust decision, and the trusted `PATH`
the rest of `hyprchroma` uses stays as it is. The status line
(`"starship": ...`, line 145 area) uses the same function.

### 3. Tests

- `tests/runtime-targets.sh` (renderer): a case with no `starship` on
  `PATH` but one in a fake per-user profile → `starship.toml` written,
  status `prompt-refresh`. The per-user directory is a parameter for the
  test (`HYPRCHROMA_STARSHIP_EXTRA_PATH`, default empty, appended to the
  two profile paths) so it runs in the sandbox without `/etc/profiles`.
- `flake.nix` module-eval checks (`noStylixSystem`): the shell entry's
  `before` contains `reloadSystemd`; its data contains the palette guard,
  `hyprchroma shell` and the `rm -f` branch; a system with every shell
  target off has none of the render line.
- A new shell test (`tests/shell-activation.sh`, registered like
  `runtime-targets`): runs the generated activation data with a stub
  `hyprchroma` and palette in a temporary home:
  1. changed base → render called once, after the copy;
  2. source removed → base removed, render called;
  3. palette fails → no render, no `shell.json`, exit 0;
  4. render fails → warning on stderr, exit 0;
  5. `DRY_RUN=1` → nothing written, nothing called.

## Alternatives rejected

- **`hyprchromad` watches `starship.base.toml`.** A new watcher for a file
  written only at activation; it needs the graphical session, and the
  daemon's event loop is upstream code we would have to patch.
- **Add `starship.base.toml` to the sync fingerprint** (upstream
  `bin/hyprchroma:970-981`). A switch still triggers no sync, so the
  fingerprint is never checked; it fixes nothing on its own.
- **Restart `hyprchromad` from activation** (`X-Restart-Triggers` on the
  base's hash). Restarts every framework sync for a prompt change, needs a
  running session, and the base is not a Nix-known path when the user
  writes `~/.config/starship.toml` by hand.
- **Add the per-user profile to the trusted path.** Widens what every
  helper may execute to a user-influenced profile, for a lookup that does
  not execute anything.

## Risks

- **Render cost at every switch:** one Python run, about 0.1 s. Measured
  on p620 in verification.
- **Open shells re-source the theme file** because its mtime changes
  (`modules/nixos.nix:318-340`), even when its content did not. Cheap, and
  the same as after any theme change today.
- **Activation without a session** (p510 headless switch, CI VM): the
  palette exists when a theme has been applied, so the render runs; it
  writes only files under the user's home, no session bus. Covered by
  shell test case 3 for the no-palette home.
- **Two concurrent renders** (activation and the restarted daemon): both
  write by atomic rename through `hyprchroma-state write-file`, and both
  read the same base after the reorder, so the last write wins with the
  same content.

## Verification

- `nix flake check` in the worktree: existing checks plus the new
  module-eval assertions and `shell-activation` test.
- Break proofs (each must turn a check red, then restore): drop
  `reloadSystemd` from `before`; drop the palette guard; drop the
  `rm -f` branch; drop the extra profile paths from `starship_installed`.
- p620, after deploy: add `[status] disabled = false` to the starship
  settings in a scratch branch, switch, and check a new terminal and
  `grep status ~/.config/omarchy/runtime/starship.toml` without logging
  out; revert and switch again; time the activation entry from the
  journal.
- razer and p510 get the change with the next normal deploy (p510 with the
  owner's OK).
