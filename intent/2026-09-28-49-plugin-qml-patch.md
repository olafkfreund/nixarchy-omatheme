---
status: approved
issue: 49
author: olafkfreund
---

# Intent: Replace the inline plugin QML rewrite

## Problem

The plugin package embeds a large Python program in `pkgs/omarchroma-plugin.nix`
to rewrite upstream `Panel.qml` during every build. The rewrite is difficult to
review, duplicates the generated QML inside Nix strings, and depends on fragile
text markers.

## Proposed outcome

The plugin applies a checked-in patch to upstream `Panel.qml`. The resulting
plugin keeps the current runtime status display and palette actions while
upstream source changes fail clearly during the package build.

## Affected users and systems

NixOS users of the nixarchy-omatheme module and the Omarchy bar plugin,
including the Razer test host.

## Constraints

- Preserve the current plugin manifest and runtime behavior.
- Keep the existing Omarchroma source and package interface.
- Do not modify the user NixOS configuration repository.
- Verify the plugin build and existing runtime checks before publishing.

## Open questions

None.
