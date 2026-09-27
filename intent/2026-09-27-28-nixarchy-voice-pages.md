---
status: draft
issue: 28
author: olafkfreund
---

# Intent: Make the omatheme Pages site part of the Nixarchy web family

## Problem

The current nixarchy-omatheme GitHub Pages site uses a custom marketing-card
layout that does not match the Nixarchy documentation and plugin sites. The
visual language, navigation, reading width, typography, and code examples are
different from the established Nixarchy Voice reference, so the project feels
separate from the ecosystem it extends.

## Proposed outcome

The site looks and reads like the Nixarchy Voice page while remaining specific
to nixarchy-omatheme. It uses the same ASCII masthead treatment, JetBrains
Mono typography, dark palette, centered navigation, narrow documentation
column, code blocks, callouts, links, and responsive behavior.

The page still explains the NixOS module, Stylix boundary, rebuild-free theme
switching, runtime bridges, installation path, and Razer demo screenshots and
recording. The existing static GitHub Pages deployment remains sufficient.

## Affected users and systems

- Visitors to `https://olafkfreund.github.io/nixarchy-omatheme/`.
- `site/index.html` and `site/style.css`.
- Existing repository-local showcase media.
- GitHub Pages deployment from `main`.

## Constraints

- Match the Nixarchy Voice reference closely without copying unrelated prose.
- Keep the page static; no JavaScript framework or new build dependency.
- Preserve accessible headings, alt text, keyboard-focusable links, readable
  contrast, and mobile responsiveness.
- Keep all existing install and source links useful.
- Retain the demo video and before/after screenshots.
- Do not change the NixOS module or runtime engine.

## Open questions

- None; the supplied Nixarchy Voice page is the design reference.
