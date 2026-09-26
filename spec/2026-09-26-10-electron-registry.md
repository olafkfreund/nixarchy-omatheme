---
status: approved
issue: 10
intent: intent/2026-09-26-10-electron-registry.md
---

# Spec: Verified Electron application registry

## Design

Add a small registry beside the existing Electron adapter with one record per
application. Each record contains an identifier, support state, configuration
boundary, synchronization command, and reload semantics. The registry is
implemented in the existing `pkgs/hyprchroma-electron` helper rather than as a
new service or framework.

The initial registry contains:

- `vscode`: supported, opt-in, updates only generated
  `workbench.colorCustomizations` entries in `Code/User/settings.json`, and
  reports that the window must be reloaded.
- `discord`: unsupported and inert. It reports unsupported without reading or
  writing Discord files.
- Other known Electron applications: unsupported by default and not mutated.

The NixOS module keeps the existing explicit VS Code option and adds no
automatic enablement for unsupported applications. The renderer writes a
machine-readable Electron status file below
`$XDG_STATE_HOME/hyprchroma/electron.json`, using the existing atomic state
writer. The Omarchroma panel watches that file and displays compact statuses
next to terminal statuses.

Application detection is path/package based only where the adapter needs a
configuration file; absence is reported as unavailable rather than creating
application state. The registry never follows store-linked configuration files
and never rewrites unknown JSON keys.

## Alternatives rejected

### Mutate every Electron application's preferences

Rejected because Electron applications do not share a theme schema or reload
contract. This would risk corrupting settings and would make Discord's crash or
future application changes appear to be theme-engine behavior.

### Add Discord CSS or application patching

Rejected because it would depend on private Discord internals and violate the
ownership boundary. Discord remains explicitly unsupported until a stable,
user-owned configuration and safe reload path can be demonstrated.

### Create a generic plugin framework

Rejected as unnecessary for the current registry size. A plain registry and
small adapter dispatch are sufficient; a framework can be introduced only when
multiple verified adapters require shared lifecycle behavior.

## Risks

- VS Code settings may be store-linked or malformed; the existing refusal and
  parse-error behavior must remain unchanged.
- A status file can become stale if an application exits before reloading; the
  state must describe the last synchronization result, not claim live reload
  without evidence.
- Electron application identifiers may differ between NixOS package names and
  desktop IDs; unsupported detection must fail closed.
- The plugin's external QML source is patched during packaging, so marker
  checks must fail the build if upstream layout changes.

## Verification

- Evaluate the NixOS module with Stylix enabled, disabled, and VS Code disabled.
- Run the VS Code adapter against preserved settings, malformed JSON, and a
  symlink; verify unrelated settings remain unchanged and unsafe links are
  refused.
- Run the Discord/unsupported registry entry and verify no application file is
  created or changed.
- Build the engine and plugin, validate the plugin manifest, and check generated
  QML contains the Electron status reader.
- On Razer, activate a temporary system generation, verify status output and
  panel files, then restore the original generation and confirm the NixOS
  configuration worktree is clean.
