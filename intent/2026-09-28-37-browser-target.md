---
status: draft
issue: 37
author: olafkfreund
---

# Intent: Opt-in browser theme target

## Problem

The pinned Omarchroma runtime supports synchronizing browser profiles, but the
NixOS module does not expose that capability as a target and the Nixarchy
plugin does not show its status. Users cannot declaratively opt into browser
theming or distinguish synchronized, deferred, and unavailable browser work.

Browser profile databases are also different from ordinary theme files:
Chromium and Firefox may keep them open, so writes must be deferred safely
until the browser exits.

## Proposed outcome

NixOS users can enable an explicit
`programs.nixarchyThemeEngine.targets.browsers` target. It is disabled by
default, participates in the existing runtime synchronization service, and
reports its state in the Omarchroma plugin. Open browser profiles are deferred
and visible as pending instead of being modified unsafely.

## Affected users and systems

- NixOS users importing this flake's `nixosModules.default` module;
- Nixarchy users importing `nixosModules.nixarchy`;
- Chromium- and Firefox-family browser profiles supported by Omarchroma;
- the Hyprchroma daemon and Omarchroma panel;
- the Razer desktop used for live acceptance testing.

## Constraints

- Do not edit `/home/olafkfreund/.config/nixos`.
- Do not enable browser profile writes by default.
- Preserve the runtime engine's close/defer and restore behavior.
- Do not write browser profiles through Home Manager or the Nix store.
- Keep Stylix declarative ownership unchanged.
- Add tests for option evaluation, default-off behavior, status rendering, and
  the runtime target command.

## Open questions

- Should browser synchronization be represented as one aggregate target or as
  per-browser options? The initial implementation should follow Omarchroma's
  aggregate `browsers` target.
- Should the browser target require an explicit dependency assertion for
  `plyvel`, or should that be handled by issue #38's runtime packaging work?
