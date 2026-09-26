---
status: draft
issue: 14
intent: intent/2026-09-26-14-alacritty-runtime-tests.md
---

# Spec: Audit Alacritty bridge and add runtime test matrix

## Design

Keep Alacritty as a declarative-wrapper bridge, not a new Hyprchroma palette
renderer. The Home Manager activation will remain the owner of the stable
Alacritty configuration: when Home Manager creates a symlink, the activation
copies its generated content to a user-owned regular file before runtime theme
hooks can update related files. The engine must not write to the Nix store or
claim Alacritty is live-synchronized unless the inspected Omarchy hook and
runtime file prove that behavior.

The audit will establish the actual Alacritty file flow from Home Manager or
Stylix, through the activation bridge, to the Omarchy theme hook. It will then
make the target matrix and Stylix guide describe that flow accurately, including
whether existing Alacritty windows require restart.

Add a small test script under `tests/` using temporary XDG homes. It will:

1. exercise the shell and terminal renderer entry points with a fixture palette;
2. verify generated files are replaced atomically and preserve user config;
3. verify generated runtime files change when the fixture palette changes;
4. verify the Alacritty bridge transformation preserves the source configuration
   and adds only the expected runtime boundary; and
5. validate status JSON and shell syntax without requiring a graphical session.

Expose the test through the existing flake checks or package check phase so CI
executes it on supported Linux systems. Keep Razer validation as a separate
manual acceptance check for actual Omarchy theme hooks and application reload
behavior.

## Alternatives rejected

- Add a dedicated Alacritty renderer immediately: rejected until the audit proves
  there is a stable runtime file and a single safe owner for it.
- Replace Stylix/Home Manager's complete Alacritty configuration: rejected because
  it would discard supported application settings and violate the ownership
  boundary.
- Test by rebuilding or changing the user's NixOS configuration: rejected because
  the behavior can be tested in isolated temporary homes and the repository must
  remain safe for users without Stylix.
- Add a full integration-test framework: rejected because shell fixtures and
  existing Nix checks cover the required behavior with less maintenance.

## Risks

- The Omarchy Alacritty hook may use a path or format that differs between
  versions; the audit must test the pinned source used by the flake.
- Copying a symlink target can preserve stale generated content if activation
  ordering is wrong.
- A test that only compares file contents could miss an application reload
  failure; live reload/restart semantics remain explicitly documented and are
  checked on Razer.
- CI may not have Alacritty installed; the fixture must test file behavior rather
  than depend on the binary.

## Verification

- `nix flake check --all-systems` passes with the new deterministic test.
- The package/module evaluation confirms the Alacritty activation remains
  present and ordered after Home Manager's `linkGeneration`.
- The temporary-home test proves preservation, atomic replacement, palette
  change propagation, status output, and shell syntax.
- Razer manually confirms the merged implementation with an Omarchy theme
  switch and verifies restoration afterward.
