---
status: draft
issue: 24
intent: intent/2026-09-27-24-nixarchy-pages-look.md
---

# Spec: Align the omatheme showcase with Nixarchy's web identity

## Design

Use the main Nixarchy Pages site as the visual reference:
<https://olafkfreund.github.io/nixarchy/>.

Keep the showcase as plain static HTML and CSS in `site/`, with no JavaScript
framework or site generator. Retain the existing Pages workflow and deploy the
contents of `site/` as its artifact.

Restructure `site/index.html` into a documentation-style showcase:

- A masthead with a compact ASCII or text logo, tagline, and links to the
  plugin repository, the main Nixarchy site, and the issue tracker.
- A centered introduction explaining that this is the NixOS runtime theme
  bridge for Omarchy/Nixarchy.
- Clear primary actions for installation and source code.
- A "see it in action" section containing the captured Razer screen recording,
  with a poster image, controls, muted autoplay only when appropriate, and a
  normal fallback link.
- A small screenshot gallery showing the menu plugin, a theme switch, and at
  least one application reflecting the changed palette.
- Short sections explaining the runtime model, Stylix boundary, supported
  targets, and NixOS installation.
- A final status/footer section linking back to Nixarchy and GitHub.

Update `site/style.css` to match the reference's JetBrains Mono/documentation
feel: dark neutral background, restrained borders, centered readable measure,
terminal-like code blocks, simple CTA buttons, modest spacing, and responsive
media. Use a system fallback if the external Google Font is unavailable; do
not make the page depend on JavaScript or a font service for readability.

Store showcase media under a repository-local `site/` subdirectory with stable
names. Prefer WebP/AVIF screenshots and a reasonably compressed MP4/WebM
recording. Every image gets descriptive alternative text, and the recording
has a text/link fallback.

Capture the Razer demo in this order:

1. Show the Nixarchy/Omarchy menu with the omatheme plugin visible.
2. Open or show a supported application surface.
3. Run a theme switch such as `omarchy theme set <theme>`.
4. Show the palette and application surface updating without a NixOS rebuild.

Before committing media, inspect the frames and remove notifications, account
names, paths, secrets, tokens, personal files, and unrelated desktop state.

## Alternatives rejected

- Copying the main Nixarchy page wholesale: rejected because the plugin needs
  its own installation, runtime, Stylix, and supported-target explanation.
- Adding a React/static-site framework: rejected because the page is small and
  the existing GitHub Pages workflow already serves static assets.
- Embedding a third-party video host: rejected because it adds availability,
  privacy, and tracking dependencies; repository-local media is sufficient.
- Capturing only screenshots: rejected because the key value is live theme
  switching without a rebuild, which a short recording demonstrates better.

## Risks

- Video files can make the repository and Pages deployment unnecessarily large;
  compression and a short recording are required.
- A capture can accidentally include private data; inspection is mandatory.
- Browser autoplay policies may block playback; the page must remain useful
  with controls and a direct fallback link.
- The reference site may evolve; copy the visual language, not its unrelated
  content or implementation details.

## Verification

- Inspect the rendered page locally and compare its typography, spacing,
  navigation, CTA treatment, code blocks, and media presentation with the main
  Nixarchy page.
- Check every local media path and link from `site/index.html`.
- Confirm images have useful `alt` text and the video has controls plus a
  fallback link.
- Test the layout at desktop and narrow viewport widths.
- Run `git diff --check`.
- Run `nix flake check --no-build --accept-flake-config`.
- Confirm the existing Pages workflow can deploy the resulting `site/` tree.
