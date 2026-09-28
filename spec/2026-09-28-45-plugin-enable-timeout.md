---
status: draft
issue: 45
intent: intent/2026-09-28-45-plugin-enable-timeout.md
---

# Spec: enabling the Omarchroma plugin can't stall a deploy or churn the shell

The intent was approved on 2026-09-28 with the recommended answers:

| # | Question | Decision |
| --- | --- | --- |
| 1 | Run from HM activation? | Login only, plus one non-blocking kick |
| 2 | Timeouts | 15 s per IPC call, at most 5 attempts, `TimeoutStartSec=90` |

## Design

All changes are in `modules/nixos.nix`.

### 1. The switch no longer starts the unit (why HM blocked)

Home Manager's activation didn't call the script directly. Its
`reloadSystemd` step (sd-switch) started the unit because its `ExecStart`
changed, and it waited for the `oneshot` to finish. The unit gets:

```nix
Unit.X-SwitchMethod = "keep-old";
```

Home Manager's `systemd.nix` declares this option (enum `reload`, `restart`,
`stop-start`, `keep-old`), and the installed sd-switch 0.6.3 honours it. On
a switch, the changed unit is left alone. It still runs at every login
through `WantedBy = graphical-session.target`.

### 2. One non-blocking kick at activation

A new activation entry, `nixarchyThemeEnginePluginKick`, ordered after
`reloadSystemd`:

```sh
if systemctl --user is-active --quiet graphical-session.target; then
  run systemctl --user start --no-block nixarchyThemeEnginePlugin.service || true
fi
```

`--no-block` queues the start and returns immediately. Activation never
waits, and a deploy to a live session still enables the plugin within
seconds. It is skipped when no graphical session is running (for example
a headless build).

### 3. A bounded unit and a gentler script

The unit gains `Service.TimeoutStartSec = 90`.

`pluginEnableScript`:

- exports `OMARCHY_SHELL_IPC_TIMEOUT=15s`
- runs `rescanPlugins` **once**, before the loop
- makes at most **5** `enablePlugin` attempts, sleeping 1, 2, 4 and 8 s
  between them. The worst case is 5 × 15 s + 15 s = 90 s, the unit's limit.
- succeeds on `ok`. An already-enabled plugin also answers `ok`: verified by
  hand on p620, where the plugin was already loaded.
- on failure, prints how many attempts it made and exits 1

### 4. A test with a stubbed `omarchy-shell`

`tests/plugin-enable.sh`, wired as a flake check like the existing
`runtime-targets` check. It runs the built script with a stub `omarchy-shell`
on `PATH`. The stub logs each call and answers from a scripted sequence.

- **Slow shell:** the first two `enablePlugin` calls return empty, then
  `ok`. Expect exit 0, exactly **1** `rescanPlugins`, and 3 `enablePlugin`
  calls.
- **Dead shell:** always empty. Expect exit 1 after exactly **5**
  `enablePlugin` calls and 1 `rescanPlugins`.
- **Timeout is passed:** the stub records `$OMARCHY_SHELL_IPC_TIMEOUT` and
  it must be `15s`.

The sleeps make the dead-shell case take about 15 s. That's acceptable for a
check.

## Alternatives rejected

- **Only raise the IPC timeout:** it fixes today's timing, but a truly hung
  shell would still hold activation for 30 × timeout, and every retry would
  still rescan.
- **Run at login only, with no activation kick:** after a deploy the plugin
  stays unenabled until the next login.
- **Make the unit `Type=simple`:** sd-switch wouldn't wait for it, but
  failures would lose their meaning (the unit is "active" at once), and the
  restart-on-change behaviour would remain.

## Risks

- **`keep-old` is ignored by some future sd-switch** (all hosts): the unit
  is still bounded to 90 s, so the worst case is a slow deploy, not a stuck
  one.
- **The kick fires before the new shell is ready** (live session): the
  script's own retries cover up to ~90 s, and the next login covers the rest.
- **Five attempts aren't enough on a very slow start** (login): the unit
  fails visibly, and the next login or theme switch retries. That's better
  than a silent 5-minute stall.

## Verification

1. **Red first:** `tests/plugin-enable.sh` against the current script fails:
   the slow-shell case sees 3 rescans, not 1, and the timeout variable is
   unset.
2. **Green:** with the fix, the check and `nix flake check` pass.
3. **Unit file:** a built Home Manager test configuration's unit contains
   `X-SwitchMethod=keep-old` and `TimeoutStartSec=90`.
4. **Live, after rollout:** a p620 switch shows no `home-manager-olafkfreund`
   timeout and exits 0. `nixarchyThemeEnginePlugin` finishes `success`
   within 90 s (started by the kick), and the bar has content afterwards.
