---
status: draft
issue: 7
intent: intent/2026-09-26-7-runtime-app-bridges.md
---

# Spec: Runtime bridges for remaining desktop applications

## Design

Add a terminal adapter layer to Hyprchroma. Each adapter owns one mutable
runtime theme file below `~/.config/omarchy/runtime/` and never writes a
Stylix/Home Manager store path.

### Kitty

Generate `~/.config/omarchy/runtime/kitty.conf` from the active Omarchy
palette. The declarative Kitty configuration imports that file. If Home
Manager links `kitty.conf` from the store, the NixOS module copies the linked
wrapper to a regular user-owned file after `linkGeneration`, preserving the
user's declarative settings and import boundary.

After writing the runtime colors, use Kitty's remote-control interface with
`set-colors --all --configured` when a running Kitty instance is reachable.
If remote control is unavailable, mark Kitty as synchronized-for-new-windows
and report that existing windows require a reload or restart. Kitty's native
configuration reload is available through its reload action or `SIGUSR1`.

Reference: https://sw.kovidgoyal.net/kitty/remote-control/ and
https://sw.kovidgoyal.net/kitty/conf/.

### Foot

Generate `~/.config/omarchy/runtime/foot.ini` containing the `[colors]`
section from the active palette. The declarative `foot.ini` imports this file
from its `[main]` section. Apply the same post-Home-Manager regular-file
bridge used for Alacritty when the wrapper is store-linked.

Foot supports importing an absolute configuration file. Its dark/light signal
interface changes between `[colors-dark]` and `[colors-light]`, but it is not a
general arbitrary-palette reload mechanism. Therefore the adapter writes the
file for new clients and reports existing Foot windows as restart-required
unless a verified server reload path is available on the host.

Reference: `foot.ini(5)`, especially the `include` option and server signal
behavior.

### Ghostty

Generate `~/.config/omarchy/runtime/ghostty.conf` using Ghostty's native
configuration syntax. The declarative Ghostty configuration loads it through
`config-file`, preserving the rest of the Stylix/Home Manager configuration.
The same post-activation bridge converts a store-linked wrapper to a regular
file.

When the Ghostty user service is active, reload it with
`systemctl --user reload app-com.mitchellh.ghostty.service`. Otherwise use the
application's reload action when available and report restart-required when
no safe running instance can be addressed. The adapter must not signal an
arbitrary process by PID.

Reference: https://ghostty.org/docs/config and
https://ghostty.org/docs/linux/systemd.

### Electron applications

Do not treat Electron as one universal full-color target. Electron applications
do not expose a common user-session API for arbitrary palette replacement.
Implement two layers:

1. A generic, opt-in dark/light adapter that follows the Omarchy palette mode
   through the desktop preference and reports applications that need a
   restart. This covers Chromium's `prefers-color-scheme` behavior where the
   application honors it, but does not claim custom palette synchronization.
2. A per-application adapter registry for applications with a documented
   theme file or command interface. Each entry declares its config path,
   ownership mode, renderer, and reload/restart command. Store-linked paths
   are rejected unless a regular-file wrapper is explicitly configured.

The first registry entries are discovered from Razer rather than assumed:
VS Code, Obsidian, Slack, Spotify, and Discord are installed there. An entry
is added only after its config format, Stylix/Home Manager ownership, and
reload behavior are verified. Applications without a verified entry remain
reported as unsupported instead of receiving a speculative mutation.

### NixOS/Home Manager interface

Expose the adapters behind feature flags:

```nix
programs.nixarchyThemeEngine.targets = {
  kitty = true;
  foot = true;
  ghostty = true;
  electron = false;
};

programs.nixarchyThemeEngine.electron.apps = {
  vscode.enable = true;
};
```

The exact option names may be simplified during planning if one option is
sufficient. Defaults must avoid changing application-specific files until an
adapter has passed live verification. The no-Stylix path receives generated
wrappers and runtime files from the module; the Stylix path keeps Stylix as
the declarative template and disables no additional static Stylix targets.

The status model gains explicit states for `synchronized`,
`new-windows-only`, `restart-required`, `unsupported`, and `disabled`. The
plugin displays these states rather than presenting a successful write as a
successful visible reload.

## Alternatives rejected

### Rewrite every terminal configuration directly

Rejected because it would overwrite Home Manager/Stylix-owned files, lose
user settings, and recreate the Alacritty failure already found on Razer.

### Use one generic Electron color-file format

Rejected because Electron applications do not share a common configuration
file or reload protocol. A registry with verified adapters is safer and more
honest.

### Restart every application unconditionally

Rejected because it can destroy user work and is unnecessary for Kitty and
Ghostty when their native reload paths are available.

### Make all targets enabled by default immediately

Rejected because Foot, Ghostty, Kitty, and Electron may not be installed or
may have user-owned configurations with incompatible ownership. Defaults will
be enabled only after the Razer acceptance matrix passes.

## Risks

- A terminal wrapper may contain settings that are not safe to copy or mutate;
  the bridge must copy only after validating the source is a regular file.
- Kitty remote control may be disabled or protected by a password.
- Foot may require restarting existing clients for arbitrary color changes.
- Ghostty service reload may not reach instances launched outside its user
  service.
- Electron application formats and reload behavior vary by release.
- A runtime-generated file can be overwritten by a later Home Manager
  activation; the bridge must run after `linkGeneration` every time.
- Existing applications can remain visually stale even when the runtime file
  was written successfully.

## Verification

- Evaluate NixOS modules with Stylix absent, Stylix detected, and forced
  runtime mode.
- Build and shell-check all adapter scripts.
- Use temporary XDG directories to verify generated Kitty, Foot, and Ghostty
  syntax and ownership behavior.
- On Razer, verify the installed terminal configuration wrappers are regular
  files and preserve their imports.
- Switch between two Omarchy themes and inspect each adapter's status state.
- Verify Kitty reload, Ghostty service reload, and Foot restart reporting.
- Add and test only the Electron applications whose interfaces are verified.
- Run `nix flake check`, `omarchy plugin validate`, and the existing Razer
  temporary-system build before merge.
