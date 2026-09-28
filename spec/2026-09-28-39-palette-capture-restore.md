---
status: approved
issue: 39
intent: intent/2026-09-28-39-palette-capture-restore.md
---

# Spec: Expose palette capture and restore in the theme plugin

## Design

Expose the existing engine primitives through the Omarchroma plugin:

- `hyprchroma palette --capture` saves the current canonical palette through
  the existing atomic state writer.
- `hyprchroma restore --captured` restores the captured application state.
- `hyprchroma restore --stock` restores the stock state recorded by the
  engine.

Add small plugin actions for capture, restore-captured, and restore-stock. The
actions run as user-session processes, show success or failure in the existing
plugin feedback path, and refresh the existing status watchers after
completion. No new snapshot format, database, or derived-file copier is
introduced. The canonical palette remains the only mutable source; target
files continue to be rendered by the normal synchronization path.

Keep all state under the existing user-owned XDG configuration/state/data
directories. The plugin passes fixed arguments and does not accept arbitrary
filesystem paths, so the UI cannot turn the action into a path-write
primitive.

## Alternatives rejected

- **Named snapshot files:** duplicates the already-supported capture/restore
  model and creates an additional format and migration problem.
- **Copying every generated target file:** risks conflicting with Stylix or
  Home Manager ownership and bypasses application reload/status handling.
- **NixOS options for snapshots:** snapshots are runtime user state and should
  not require evaluation or a rebuild.
- **A separate daemon/API:** the existing `hyprchroma` commands already hold
  the synchronization lock and provide the required atomic behavior.

## Risks

- Restoring stock or captured state may require application restart for targets
  that cannot reload live; the existing status output remains authoritative.
- A capture with no resolvable palette should fail visibly and leave runtime
  files unchanged.
- The plugin is patched against upstream QML, so upstream layout changes can
  require updating insertion markers.

## Verification

- Build the patched plugin and pass its insertion-marker checks.
- Verify the generated plugin contains all three fixed command actions.
- Run the existing module, runtime, desktop, and Electron checks.
- Add a shell-level test that uses stubbed engine commands to confirm capture,
  captured restore, and stock restore dispatch the expected arguments.
- Confirm formatting and static analysis behavior.
