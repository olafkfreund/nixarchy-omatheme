---
status: approved
issue: 53
author: olafkfreund
---

# Intent: Add live Vim and Neovim theme targets

## Problem

Omarchroma currently synchronizes desktop, terminal, shell, browser, Electron,
and Flatpak surfaces, but not Vim or Neovim. LazyVim users therefore need a
separate editor theme path and do not receive rebuild-free theme changes.

## Proposed outcome

The NixOS module exposes declarative `vim` and `neovim` targets. Theme switches
generate runtime Vimscript and Lua colors, and running editors reload their
highlights without a NixOS rebuild. LazyVim is supported through the Neovim
target, without a separate LazyVim target. Stylix remains usable for
declarative initial configuration.

## Affected users and systems

NixOS users of nixarchy-omatheme, including users with Home Manager, Stylix,
plain Neovim, LazyVim, NixVim, nvf, or classic Vim. The Razer test host is the
runtime acceptance host.

## Constraints

- Reuse the existing canonical Omarchy palette and runtime daemon.
- Do not add a separate LazyVim implementation.
- Work with and without Stylix.
- Avoid requiring Neovim TCP RPC or Vim client-server support for basic reloads.
- Keep generated files in the Omarchy runtime directory and install only small
  editor bridge plugins through Home Manager.
- Do not modify the user NixOS configuration repository.

## Open questions

None.
