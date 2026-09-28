---
status: approved
issue: 45
spec: spec/2026-09-28-45-plugin-enable-timeout.md
---

# Plan: enabling the Omarchroma plugin can't stall a deploy or churn the shell

Branch `fix/45-plugin-enable-timeout`, in a worktree of
`/mnt/data/Source-home/GitHub/nixarchy-omatheme`. The local checkout is not
touched.

## Approved decisions

These are carried over from the spec. All changes are in
`modules/nixos.nix`, plus one test and one check.

**D1.** `systemd.user.services.nixarchyThemeEnginePlugin.Unit.X-SwitchMethod
= "keep-old"`. sd-switch no longer starts or waits for the changed unit
during Home Manager activation.

**D2.** Add `home.activation.nixarchyThemeEnginePluginKick`, with
`after = [ "reloadSystemd" ]` and `lib.mkIf cfg.managePlugin`:

```sh
if systemctl --user is-active --quiet graphical-session.target; then
  run systemctl --user start --no-block nixarchyThemeEnginePlugin.service || true
fi
```

**D3.** `Service.TimeoutStartSec = 90` on the unit.

**D4.** `pluginEnableScript`:

```sh
set -u
export OMARCHY_SHELL_IPC_TIMEOUT=15s
plugin_id=io.github.nobledoodle.omarchroma
placement='{"section":"right"}'
if ! command -v omarchy-shell >/dev/null 2>&1; then
  echo "nixarchyThemeEngine: omarchy-shell not found" >&2
  exit 1
fi
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
delay=1
for attempt in 1 2 3 4 5; do
  reply=$(omarchy-shell shell enablePlugin "$plugin_id" "$placement" \
    2>/dev/null || true)
  if [ "$reply" = ok ]; then
    exit 0
  fi
  [ "$attempt" = 5 ] || { sleep "$delay"; delay=$((delay * 2)); }
done
echo "nixarchyThemeEngine: Omarchy Shell did not enable $plugin_id" \
  "after 5 attempts" >&2
exit 1
```

**D5.** `tests/plugin-enable.sh` plus a `pluginEnable` flake check. The
check reads the unit from the existing test system (the same way
`serviceFor` reads `hyprchromad`):

- It takes `ExecStart`, which is the built script, and runs it under a stub
  `omarchy-shell` for the slow-shell, dead-shell and timeout-variable cases
  from the spec.
- It asserts at evaluation that `Unit.X-SwitchMethod == "keep-old"` and
  `Service.TimeoutStartSec == 90`.
- `bash` and `coreutils` go in `nativeBuildInputs`.

## Steps

1. **Test first** (D5, test and check only) → verify:
   `nix build .#checks.x86_64-linux.pluginEnable` **fails**. The slow-shell
   case sees 3 `rescanPlugins` rather than 1, or the timeout variable is
   unset. The unit assertions fail too.
2. **The fix** (D1–D4) → verify: the check passes.
3. **`nix flake check`** → verify: it passes. The `runtime`, `desktop` and
   `electron` checks are unaffected.
4. **Commit** as `fix(plugin): bound the Omarchroma enable, and keep it out
   of Home Manager activation (#45)`, push, and open a PR linking the intent,
   spec and plan.
5. **Merge** on green CI (squash, pinned to the head commit).
6. **Rollout:** a nixarchy pin bump (in a PR of its own, or together with
   #1040's pin if that hasn't merged yet), then the nixos_config lock, then
   deploy p620 and razer, bus-announced → verify the spec's live check:
   - the p620 switch exits 0, with no Home Manager timeout
   - the unit finishes `success` within 90 s
   - the bar has content afterwards

## Tests

| # | Command | Expected |
| --- | --- | --- |
| T1 | step 1 check | fails on rescans, the timeout or the unit attrs |
| T2 | step 2 check | passes |
| T3 | `nix flake check` | passes |
| T4 | step 6 live deploy | exit 0, the unit succeeds, the bar has content |

## Rollback

- **Before merge:** close the PR.
- **After merge:** `git revert` the step-4 commit. Hosts keep the old unit
  until the next deploy. Its workaround is
  `systemctl --user stop nixarchyThemeEnginePlugin`.
