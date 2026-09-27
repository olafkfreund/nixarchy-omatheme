---
status: draft
issue: 24
author: olafkfreund
---

# Intent: Align the omatheme showcase with Nixarchy's web identity

## Problem

The nixarchy-omatheme GitHub Pages site is live, but its custom marketing
landing-page treatment does not share the documentation, terminal, and
NixOS-native feel of the main Nixarchy site. The relationship between the
plugin and Nixarchy is therefore weaker than it should be.

## Proposed outcome

The showcase presents nixarchy-omatheme in the same visual language as the main
Nixarchy page: terminal-oriented typography, restrained dark styling, centered
documentation-like content, clear install and source links, and concise
plugin-specific examples. It remains a static GitHub Pages site and explains
the runtime theme engine, Stylix boundary, and NixOS installation path.

The showcase also includes a real Nixarchy runtime demonstration captured on
the Razer desktop: screenshots and a short screen recording showing the menu
plugin, a theme switch, and the resulting application updates. These assets
make the live behavior verifiable to users instead of describing it only in
text.

## Affected users and systems

- Visitors to `https://olafkfreund.github.io/nixarchy-omatheme/`.
- The repository's `site/index.html` and `site/style.css` assets.
- The Razer desktop used to produce reproducible demo screenshots and a
  screen recording.
- Repository-local showcase media assets referenced by the Pages site.
- GitHub Pages deployment from the `main` branch.

## Constraints

- Match the main Nixarchy site's visual feel without copying unrelated content.
- Keep the page static and deployable by the existing Pages workflow.
- Preserve accessible headings, links, readable contrast, and responsive layout.
- Capture the demo without exposing secrets, private notifications, personal
  data, or unrelated desktop state.
- Prefer compressed, repository-local media with useful alternative text and a
  fallback link for browsers that cannot play the recording.
- Do not add a JavaScript framework, build pipeline, or unnecessary dependency.
- Do not change the NixOS module or runtime engine behavior.

## Open questions

- None for the visual alignment; the implementation should use the current
  Nixarchy page as the design reference.
