---
status: draft
issue: 38
intent: intent/2026-09-28-38-runtime-dependencies.md
---

# Spec: Package Omarchroma runtime dependencies on NixOS

## Design

Extend `pkgs/hyprchroma.nix` with a Nix-provided Python runtime containing
`python3Packages.plyvel`, the dependency used by Omarchroma's Chromium profile
and Dark Reader integration. Use that interpreter in the packaged scripts and
in the trusted runtime path so the dependency is available without pip or
mutable activation-time installs.

Keep browser synchronization disabled by default in the NixOS module. When a
user opts into the browser target, the engine can use the packaged dependency;
when the target is disabled, no browser profile is touched. If the upstream
runtime reports a missing or unsupported profile, preserve that status rather
than failing the daemon.

Verify the upstream GTK/libadwaita requirement against Nixpkgs package names
(`gnome-themes-extra`, `adwaita-icon-theme`, and `adwaita-qt`) and document
them as host/runtime inputs only if the target scripts require them. Do not
force desktop theme packages into every engine closure when the scripts only
consume user configuration and CSS.

Add package-level checks that confirm the packaged Python interpreter imports
`plyvel`, and retain the existing runtime checks for non-browser targets.

## Alternatives rejected

- **Manual pip installation:** not reproducible and incompatible with the
  immutable NixOS runtime.
- **A second browser-only engine package:** adds package and module-selection
  complexity before a measurable closure-size problem exists.
- **Installing all GTK, Qt, and browser assets unconditionally:** increases
  closure size and may duplicate host-level Stylix or desktop packages.
- **Making browser synchronization default-on:** browser profile databases are
  user-owned state and should only change after explicit opt-in.

## Risks

- The upstream scripts may import additional Python modules in future
  versions; the package check should fail early when that happens.
- `plyvel` may increase the closure size for users who never enable browsers.
- GTK/libadwaita behavior may depend on the host desktop environment rather
  than the engine package alone.
- Browser profile formats and locks can change, so synchronization must remain
  deferred or status-reporting when a browser is running.

## Verification

- Evaluate the package with the pinned nixpkgs.
- Build `hyprchroma` and verify the runtime interpreter imports `plyvel`.
- Run the module, runtime-target, desktop-runtime, and Electron checks.
- Confirm the default browser target remains `false` and the opt-in command is
  emitted only when enabled.
- Run formatting and static analysis, recording any pre-existing warnings.
