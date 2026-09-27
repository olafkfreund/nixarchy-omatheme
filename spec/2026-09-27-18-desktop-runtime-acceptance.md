---
status: draft
issue: 18
intent: intent/2026-09-27-18-desktop-runtime-acceptance.md
---

# Spec: Desktop runtime target acceptance

## Design

Add one fixture-driven desktop acceptance test beside the existing runtime and
Electron tests. The test will execute the packaged target commands with isolated
`XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, and `HOME` directories,
using only temporary fixtures and command stubs where the upstream renderer
expects an installed application or desktop portal.

The matrix covers the existing target names from `modules/nixos.nix`:

- GTK/libadwaita
- Qt/KDE
- Dark Reader
- Pear
- Flatpak

For each target, the test will verify the smallest observable contract already
promised by the engine: enabled synchronization succeeds, the expected
user-owned artifact or renderer action is produced, disabled synchronization is
safe and does not rewrite the fixture, and unavailable integrations are
reported as unavailable rather than as synchronized. The test will also render
two palettes and verify that enabled mutable artifacts change while unrelated
files remain byte-for-byte unchanged.

Extend `flake.nix` with a `desktop` check that runs this test against the
packaged `hyprchroma` output. Keep existing `runtime`, `electron`, and `module`
checks unchanged except for any shared test setup that is demonstrably useful.

Use the existing module target commands and the upstream `omarchroma` scripts;
do not introduce a second target protocol or a new status registry for this
task. If a target has no deterministic artifact or supported reload result in
the current upstream source, the acceptance test records that as unavailable
or restart-required and does not claim live synchronization.

The Razer verification is a host smoke check only. It runs the packaged target
commands against the real user session, records the resulting target status,
and does not install applications, alter Flatpak permissions, or edit the
NixOS configuration repository.

## Alternatives rejected

- **Add new adapters for every desktop application:** rejected because this
  task is about proving the existing target surface, not expanding support.
- **Test against the live desktop in CI:** rejected because it is fragile,
  requires unavailable services, and can mutate user state.
- **Replace the upstream target scripts:** rejected because the repository
  should package and integrate the existing Omarchy behavior rather than fork
  its runtime protocol without evidence.
- **Require Stylix in the test harness:** rejected because the same module must
  work on the Nixarchy offline image without Stylix.

## Risks

- Upstream target scripts may depend on tools or paths not available in the
  Nix build sandbox; the fixture must stub only those external boundaries and
  keep renderer logic real.
- Flatpak and browser integrations may expose only restart-required or
  unavailable behavior in a headless test environment.
- A host smoke check can reflect Razer’s installed applications rather than
  universal support; its output must remain informational, not a CI gate.
- The upstream `omarchroma` input can change target behavior independently of
  this repository; failures should identify the target and artifact involved.

## Verification

- `nix flake check --no-build --accept-flake-config` evaluates the added check
  and existing module assertions.
- `nix build .#checks.x86_64-linux.desktop` passes the isolated desktop matrix.
- Existing runtime and Electron checks continue to pass.
- On Razer, run the packaged desktop target smoke check and capture the status
  for each target without changing `/home/olafkfreund/.config/nixos`.
- `git diff --check` is clean and the final branch contains no generated user
  configuration.
