---
status: draft
issue: 16
intent: intent/2026-09-26-16-electron-runtime-integrations.md
---

# Spec: Expand verified Electron runtime integrations

## Design

Keep VS Code as the only supported color adapter until another application's
configuration and reload contract is verified. Expand the Electron registry to
represent the applications relevant to Razer—VS Code, Discord, Slack, and
Obsidian—with explicit capability metadata and safe status output. Unsupported
entries must return successfully without changing files, while unavailable
entries must report that their expected configuration is absent.

The adapter registry will separate these concerns:

- application identifier and configuration path;
- supported, unavailable, refused, restart-required, or unsupported state;
- the generated settings keys owned by the adapter; and
- a human-readable reason when an application cannot be safely adapted.

The existing VS Code adapter will retain its marked/generated-key boundary and
preserve all unrelated `settings.json` content. The registry will not write
Electron Local Storage, SQLite, cache, session, or package/ASAR files. It will
not launch applications to force reloads; status will continue to report
`restart-required` where appropriate.

Based on the Razer audit, Discord, Slack, and Obsidian remain explicitly
unsupported in this change. Discord's official theme controls are application
managed; Slack's custom themes are workspace/application preferences; and
Obsidian themes are vault-scoped. These facts do not provide a stable,
user-owned global color file for a safe runtime adapter. The registry and menu
will expose those states rather than guessing at internal databases.

Add isolated tests covering:

1. VS Code preservation of unrelated settings and replacement of generated
   colors across two fixture palettes;
2. unsupported Discord, Slack, and Obsidian calls changing neither fixture
   configuration files nor application state;
3. unavailable and store-linked configuration handling; and
4. status JSON containing the registry's complete, stable set of entries.

Update the target matrix, Stylix guide, README, and plugin status line to show
the expanded registry and its unsupported reasons without implying live support.
Razer acceptance will invoke only the non-mutating unsupported paths and verify
that the installed applications remain unchanged.

## Alternatives rejected

- Edit Electron Local Storage or SQLite directly: rejected because schemas are
  private, version-sensitive, and can corrupt profiles or credentials.
- Inject CSS or patch ASAR/application files: rejected because it is not a
  declarative user-owned boundary and can break updates or startup.
- Treat Slack or Obsidian as VS Code clones: rejected because their theme state
  is workspace/vault scoped and their settings formats are different.
- Mark every detected Electron application supported: rejected because detection
  does not prove a safe write or reload contract.
- Launch applications during theme switching: rejected because it can cause
  duplicate windows, crashes, or destructive profile races.

## Risks

- Electron applications can change their settings schemas without notice.
- A future adapter could accidentally overwrite user-managed generated keys;
  tests must protect the ownership boundary.
- The menu may become visually dense as registry entries grow; keep labels
  compact and expose reasons through status/help text rather than large panels.
- Discord's previous crash history makes any runtime mutation especially risky;
  it remains inert until an independent, reproducible safe boundary is proven.

## Verification

- `nix flake check --all-systems` passes.
- The Electron fixture test proves preservation, unsupported no-op behavior,
  refusal/unavailable states, and complete status output.
- Package and plugin builds pass.
- Razer confirms installed unsupported applications are not modified and the
  existing VS Code adapter remains functional.
- Documentation and the plugin agree with the registry's final states.
