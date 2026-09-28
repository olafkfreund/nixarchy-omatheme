---
status: draft
issue: 56
author: olafkfreund
---

# Intent: Publish the first omatheme release

## Problem

The runtime theme integration is merged and consumed by Nixarchy, but the
project has no versioned release or clean-install verification covering both
Stylix-enabled and Stylix-free NixOS systems.

## Proposed outcome

Users can install a versioned omatheme release, switch themes live without a
NixOS rebuild, and get the same supported runtime targets whether Stylix is
present or absent. Nixarchy consumes the release rather than an unversioned
commit pin.

## Affected users and systems

- NixOS users with Stylix.
- NixOS users without Stylix, including Nixarchy installations.
- The nixarchy-omatheme repository and Nixarchy's flake input.
- Runtime targets already supported by the plugin.

## Constraints

- Preserve rebuild-free live switching.
- Keep Stylix as the declarative template source where available.
- Preserve the standalone non-Stylix path.
- Do not duplicate application-specific theme templates unnecessarily.
- Verify the release before updating Nixarchy's input.

## Open questions

- None.
