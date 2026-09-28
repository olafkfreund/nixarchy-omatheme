---
status: draft
issue: 47
author: olafkfreund
---

# Intent: Make the omatheme runtime service resilient

## Problem

The omatheme user service can enter a restart loop on a real Nixarchy system.
The generated service invokes `hyprchroma --target=browsers`, although the
packaged CLI does not implement that target. Separately, GTK and Qt
synchronization can fail when the active Omarchy theme requests an icon theme
that is not installed, such as `Yaru-olive` on Razer where only dark variants
are available.

These failures prevent the daemon from reaching a stable active state even
though shell, terminal, palette, and other runtime bridges are usable.

## Proposed outcome

The generated service starts reliably with the targets implemented by the
selected hyprchroma package. Browser synchronization remains explicitly
opt-in and is only emitted when a compatible implementation exists.

Unavailable optional icon themes are handled as a non-fatal target condition:
the engine records/logs the condition and continues starting the daemon and
the other bridges. A valid installed icon theme remains usable through the
existing declarative configuration.

The fix is verified on Razer with a NixOS rebuild, an active
`hyprchromad.service`, and a rebuild-free theme switch.

## Affected users and systems

- Nixarchy users importing `nixosModules.default` or `nixosModules.nixarchy`.
- Stylix and non-Stylix installations using the omatheme runtime service.
- Systems whose selected theme names an icon theme not included in the system
  profile.
- Razer as the hardware integration test host.

## Constraints

- Fix service generation and runtime handling in omatheme; do not patch a
  generated unit or edit Razer's NixOS configuration as a workaround.
- Keep browser synchronization opt-in and preserve the existing target options.
- Do not make missing optional assets prevent unrelated bridges from starting.
- Keep all builds declarative and reproducible through the pinned flake.
- Preserve existing Stylix integration and non-Stylix support.

## Open questions

- Should the browser target be implemented in hyprchroma now, or should the
  service omit it until a compatible renderer exists?
- Should missing icon themes fall back automatically to an installed variant,
  or only be reported while leaving the current icon setting unchanged?
- Which runtime status value best distinguishes unsupported, unavailable, and
  synchronized targets for the plugin UI?
