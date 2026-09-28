---
status: draft
issue: 37
intent: intent/2026-09-28-37-browser-target.md
---

# Spec: Opt-in browser theme target

## Design

Expose Omarchroma's aggregate browser target through the existing NixOS module:

```nix
programs.nixarchyThemeEngine.targets.browsers = true;
```

The option defaults to `false`. When enabled, the existing user service runs
Omarchroma's `--target=browsers --set-enabled=true` command during startup and
includes `browsers` in subsequent full runtime synchronization. When disabled,
the service sends `--set-enabled=false` so Omarchroma can restore its captured
browser state safely.

The module will expose the browser state already written by the runtime in
`~/.local/state/hyprchroma/status.json`. The plugin's existing status watcher
will display browser state alongside the other desktop targets, including
`synchronized`, `pending`, `disabled`, and unavailable/not-installed states.
The browser target will not be added to the default framework toggles until
its profile-write dependency and safety behavior are covered by issue #38.

Issue #37 will not add a second browser implementation or package browser
database libraries. It will use the upstream Omarchroma runtime and leave
`python-plyvel` and GTK dependency wiring to issue #38.

## Alternatives rejected

- **Enable browser theming by default:** rejected because it writes into
  application-owned browser profiles and may affect multiple browsers.
- **Add one Nix option per browser:** rejected because Omarchroma exposes one
  aggregate target and already handles supported Chromium/Firefox families.
- **Copy browser profiles into generated files:** rejected because browser
  databases are live application state and must remain user-owned.
- **Implement browser synchronization in the NixOS module:** rejected because
  the upstream runtime already handles profile discovery, open-browser
  deferral, capture, and restoration.

## Risks

- Enabling the target without the dependency from issue #38 may report a
  runtime failure for Chromium Dark Reader profiles.
- Browser databases can remain pending while a browser process is open; the
  plugin must show that state rather than claiming an immediate update.
- The browser target may support fewer browsers on NixOS than the upstream
  Arch environment; unsupported profiles must remain unchanged.

## Verification

- `programs.nixarchyThemeEngine.targets.browsers` evaluates and defaults to
  `false`.
- The generated service includes the browser target command only when enabled.
- The plugin package contains browser status parsing and display markers.
- Existing options, plugin, formatting, and lint checks remain green.
- A runtime test confirms disabled-by-default behavior and verifies the
  status-file path without requiring a real browser profile in CI.
- Razer acceptance testing verifies a supported browser with the browser
  closed, then open, confirming synchronized versus pending behavior.
