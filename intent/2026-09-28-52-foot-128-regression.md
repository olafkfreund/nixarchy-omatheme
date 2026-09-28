---
status: draft
issue: 52
author: olafkfreund
---

# Intent: Prevent Foot 1.28 runtime theme regressions

## Problem

Foot 1.28 rejects the legacy `[colors]` section. The runtime renderer already
uses `[colors-dark]`, but the existing terminal test only checks that the file
exists and would not catch a future syntax regression.

## Proposed outcome

The CI runtime test validates the generated Foot configuration with Foot's
own parser, proving that the runtime theme file remains acceptable to Foot
1.28 and later.

## Affected users and systems

Users running Foot through the Nixarchy/omarchy runtime theme engine and the
repository's terminal renderer CI check.

## Constraints

- Keep the existing `[colors-dark]` runtime format.
- Use Foot's native `--check-config` parser; do not duplicate its grammar.
- Do not require a graphical session.
- Keep the change limited to the regression test and its CI dependency.

## Open questions

None.
