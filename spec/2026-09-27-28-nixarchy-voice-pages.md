---
status: draft
issue: 28
intent: intent/2026-09-27-28-nixarchy-voice-pages.md
---

# Spec: Make the omatheme Pages site part of the Nixarchy web family

## Design

Replace the current card-based landing page with a static documentation-style
home page shaped after the Nixarchy Voice reference.

### HTML structure

`site/index.html` will use semantic sections:

- a centered masthead with a block-character `OMATHEME` wordmark, tagline, and
  links to the manual/readme, GitHub repository, issue tracker, and Nixarchy;
- a narrow centered content column with an introductory `h1`, concise problem
  statement, and two reference-style CTA links;
- a terminal exchange showing the declarative module and rebuild-free theme
  command;
- headings for the NixOS integration, Stylix boundary, runtime targets, and
  setup instructions;
- callouts for the ownership and reload limitations;
- the existing Razer video and before/after screenshots, using native HTML
  video controls and accessible image alt text;
- a closing rule and project/license attribution.

The copy will be rewritten for this structure but will retain the current
installation links, Stylix explanation, runtime target claims, and media.

### CSS system

`site/style.css` will adopt the reference tokens and layout:

- background `#22242e`, foreground `#c9cddb`, dim text `#6b7089`;
- green accent `#a5cf5d`, blue links `#8ab4f8`, rules `#333747`, code panels
  `#1a1c24`;
- JetBrains Mono from Google Fonts with the same fallback stack;
- centered masthead and a `46rem` reading measure;
- reference-style `h1`/`h2` rhythm, links, code blocks, rules, blockquotes,
  and responsive narrow-screen behavior;
- a wider media treatment only where screenshots and video need it;
- no grid cards, decorative gradients, JavaScript, framework, or build step.

### Media and accessibility

Keep `site/media/omarchroma-switch.mp4`, the two PNG frames, and their relative
links. Use a poster image and fallback text for the video. Every image keeps a
descriptive alt attribute, headings remain ordered, and all navigation/CTA
elements remain native keyboard-focusable links.

## Alternatives rejected

- **Keep the current marketing layout:** rejected because it is visibly unlike
  the Nixarchy ecosystem and was the reason for this issue.
- **Copy the Voice page verbatim:** rejected because this page must explain a
  different project and retain its own installation, Stylix, and runtime
  content.
- **Add a CSS framework or site generator:** rejected because the reference is
  plain static HTML/CSS and GitHub Pages already serves the project directly.
- **Use JavaScript for navigation or media:** rejected because native anchors,
  headings, and video controls satisfy the page requirements.

## Risks

- Block-character wordmarks can develop seams with the wrong font or tracking;
  use the reference JetBrains Mono settings and inspect the deployed result.
- The wide media block can make the reading column feel inconsistent; keep
  prose narrow and widen only the video/screenshots.
- Relative Pages paths must work under `/nixarchy-omatheme/`; validate every
  media and stylesheet link from the deployed URL.
- The page may drift if the reference changes later; document that this is a
  deliberate snapshot of the current Nixarchy Voice style.

## Verification

- `git diff --check`.
- Verify all local stylesheet, image, video, GitHub, README, and Nixarchy links
  are present and non-empty.
- Check the HTML contains one `h1`, ordered headings, alt text for both images,
  native video controls, and no script/framework dependency.
- Run `nix flake check --all-systems --no-build` to ensure the static-page
  change does not disturb the flake.
- Push the branch and inspect the deployed GitHub Pages response and media
  URLs after CI passes.
- Review the page at desktop and narrow viewport widths before merging.
