---
status: draft
issue: 26
author: olafkfreund
---

# Intent: Make the runtime theme engine declarative on NixOS

## Problem

The runtime engine and Omarchy-compatible menu plugin currently build from the
flake, but installing them on a NixOS/Nixarchy host still requires manual
runtime steps. The Razer showcase used temporary plugin files and a temporary
user service, so the new theme version is not currently installed or running
there. This prevents users from getting a reproducible, rebuild-safe setup.

Hosts may use Stylix or may not use Stylix at all. Both groups need the same
runtime theme switching behavior, while Stylix users should retain the
application configuration coverage they already have.

## Proposed outcome

Users can enable the theme engine through a NixOS module and receive the
engine, user service, Omarchy-compatible plugin, and required runtime hooks
declaratively. `omarchy theme set <theme>` updates the supported desktop,
terminal, shell, browser/Electron, and framework targets without a NixOS
rebuild.

The module works when Stylix is enabled and when it is absent. When Stylix is
present, the runtime engine can consume its generated theme/config inputs
without replacing Stylix's declarative ownership. When Stylix is absent, the
engine provides the equivalent runtime defaults from Omarchy theme data.

The setup is tested on Razer and in a clean NixOS evaluation path, including
the Alacritty permission failure observed during the showcase capture.

## Affected users and systems

- NixOS/Nixarchy users importing the flake module.
- Stylix-enabled and Stylix-free hosts.
- The `hyprchromad` user service and Omarchroma menu plugin.
- Desktop, Kitty, Foot, Ghostty, shell, Electron, and framework bridges.
- Razer as the runtime integration test host.

## Constraints

- Keep all configuration declarative and module-based; do not edit the user's
  NixOS configuration directory directly.
- Preserve rebuild-free theme switching after installation.
- Do not require Stylix as a dependency.
- Do not duplicate Stylix's application-specific template logic where it can
  be consumed or linked safely.
- Services must use appropriate systemd hardening and least privilege.
- Validate with Nix evaluation/build checks and runtime tests on Razer.
- Follow the existing artifact gate: no implementation before an approved
  spec and plan.

## Open questions

- Which Stylix outputs can be consumed safely at runtime without taking
  ownership of generated files away from Stylix?
- Should the module expose a single enable option or separate engine/plugin
  flags?
- Which application bridges are guaranteed in the first declarative release,
  and which remain best-effort?
