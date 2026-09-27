---
status: approved
issue: 22
intent: intent/2026-09-27-22-compact-runtime-status.md
---

# Spec: Compact runtime status on narrow bars

## Design

Keep the existing four status rows and their live `FileView` models, but use
short, stable labels for the group and target names:

- Shell: `S`, `B`, `Z`, `F`
- Terminals: `K`, `F`, `G`
- Electron: `VS`, `D`, `S`, `O`
- Desktop: `G`, `Q`, `DR`, `P`, `F`

Add one QML helper for target abbreviations and keep the existing status-label
helpers as the source of truth for values. The rows will render compact text
such as `Desk G synced Q synced DR restart P n/a F off`, retain the existing
muted style, full-width anchoring, and `Text.ElideRight`, and remain single-line
so narrow bars truncate only at the end of a row. The group name remains fully
spelled out to keep the rows understandable.

Do not change the status JSON, `FileView` watchers, synchronization commands,
or fallback objects. Wide bars use the same compact labels, which avoids two
different status semantics and keeps the UI predictable.

Extend `pkgs/omarchroma-plugin.nix` generated-source assertions for the helper,
compact row text, and single-line/elision markers. Use source/build assertions
instead of adding a QML runtime framework; the repository already validates the
status data and the plugin package is the only QML build boundary.

## Alternatives rejected

- **Add responsive breakpoints and alternate row layouts:** rejected as a new
  layout abstraction for a small amount of text; compact labels solve the
  width problem without duplicate UI semantics.
- **Hide targets that are synced:** rejected because users need to see whether
  a target is unavailable, disabled, or restart-required.
- **Replace statuses with icons only:** rejected because text remains clearer
  for unsupported and future unknown values.
- **Change the runtime status schema:** rejected because the current engine and
  other consumers already use it.

## Risks

- Single-letter labels can be ambiguous; the full group names and a fixed
  abbreviation mapping keep them scoped and stable.
- A future target may not have an abbreviation; unknown target names must remain
  available through the existing raw-value fallback.
- Even compact rows can truncate at extremely narrow widths; `Text.ElideRight`
  makes this graceful, and the most important group/state text remains first.

## Verification

- `nix flake check --no-build --accept-flake-config` evaluates the plugin.
- `nix build .#packages.x86_64-linux.omarchroma-plugin --accept-flake-config`
  passes generated-source assertions.
- Existing runtime, desktop, Electron, and module checks remain green.
- `git diff --check` is clean and `/home/olafkfreund/.config/nixos` remains
  untouched.
