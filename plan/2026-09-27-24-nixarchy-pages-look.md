---
status: draft
issue: 24
spec: spec/2026-09-27-24-nixarchy-pages-look.md
---

# Plan: Align the omatheme showcase with Nixarchy's web identity

Create a static, Nixarchy-style showcase for nixarchy-omatheme and include a
privacy-reviewed Razer desktop demonstration of the plugin and live theme
switching. Keep the existing GitHub Pages workflow and do not change the
NixOS runtime implementation.

## Steps

1. Verify the clean issue branch, available Razer display/recording tools, and
   current Pages assets → confirm the approved spec is the only pending work
   and choose the smallest available capture path.
2. Run the approved Razer demo: show the menu plugin, a supported application,
   switch themes without rebuilding, and show the updated palette → verify the
   flow is visible and no private desktop content is present.
3. Export a short compressed recording, poster frame, and three useful
   screenshots into repository-local `site/` media paths → verify file sizes,
   image dimensions, playback metadata, and privacy by inspecting the assets.
4. Rewrite `site/index.html` in the Nixarchy documentation style → verify the
   page has installation/source CTAs, runtime and Stylix explanations, media
   fallback links, descriptive image alt text, and links to Nixarchy.
5. Rewrite `site/style.css` with the restrained terminal/documentation visual
   language and responsive media layout → verify desktop and narrow layouts
   remain readable without JavaScript.
6. Validate all local links/media and the Pages tree, then run repository checks
   → verify `git diff --check`, `nix flake check --no-build
   --accept-flake-config`, and the existing Pages workflow inputs pass.
7. Commit the site and media, push the branch, and open a PR linked to issue
   #24 → verify CI and Pages preview/deployment status before merging.

## Tests

- Inspect Razer captures frame-by-frame before committing them.
- Check media files with `file`, image dimensions, and video metadata.
- Verify every `src` and `href` under `site/` resolves to a repository file or
  intended public URL.
- Confirm images have `alt` text and video has `controls` plus a fallback link.
- Check the page at desktop and narrow viewport widths.
- `git diff --check`
- `nix flake check --no-build --accept-flake-config`
- GitHub Actions Pages workflow on the PR/main commit.

Expected result: the live showcase looks and feels like Nixarchy, clearly
explains this plugin's NixOS/runtime role, and proves live switching with
reviewed Razer screenshots and a short recording.

## Rollback

Revert the site/media implementation commit or revert the merged PR. The
existing Pages workflow and previous static showcase remain usable; no NixOS
module or runtime behavior is changed.
