---
status: draft
issue: 28
spec: spec/2026-09-27-28-nixarchy-voice-pages.md
---

# Plan: Make the omatheme Pages site part of the Nixarchy web family

Implement the approved static redesign of the project Pages site so it follows
the current Nixarchy Voice visual language while keeping omatheme's own
NixOS, Stylix, runtime-switching, installation, and demo content.

## Steps

1. `site/index.html`: replace the card-based marketing markup with a semantic
   masthead, block-character `OMATHEME` wordmark, tagline, ecosystem links,
   narrow documentation content, terminal exchange, integration sections,
   ownership/reload callouts, existing demo media, and attribution → verify
   the document has one `h1`, ordered headings, native links, image alt text,
   video controls, and no script dependency.
2. `site/style.css`: replace the current visual system with the Nixarchy Voice
   palette, JetBrains Mono stack, centered masthead, `46rem` reading measure,
   reference typography/link/code/blockquote/rule styles, responsive behavior,
   and a limited wide-media treatment → verify the CSS has no framework or
   gradient/card layout dependency.
3. Local static validation: check links and media references, run
   `git diff --check`, and inspect the page at desktop and narrow viewport
   widths → verify all referenced local assets exist and the layout remains
   readable.
4. Flake validation: run
   `nix flake check --all-systems --no-build` → verify the Pages-only change
   does not disturb the Nix flake checks.
5. Deployment validation: push the branch, wait for GitHub Pages/CI, and
   request the deployed HTML, stylesheet, image, and video URLs → verify the
   site works below `/nixarchy-omatheme/` before opening the PR.

## Tests

- `git diff --check`
- Static HTML/link/media checks using the repository's existing tooling or
  small standard-library checks when no dedicated checker exists.
- `nix flake check --all-systems --no-build`
- HTTP checks for the deployed Pages document, stylesheet, PNGs, and MP4.
- Manual desktop and narrow viewport review against the
  [Nixarchy Voice reference](https://olafkfreund.github.io/nixarchy-voice/).

## Rollback

Revert the implementation commit or restore the previous `site/index.html` and
`site/style.css`; no NixOS modules, generated files, or runtime services are
changed by this task.
