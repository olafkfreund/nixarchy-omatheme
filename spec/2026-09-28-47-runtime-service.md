---
status: draft
issue: 47
intent: intent/2026-09-28-47-runtime-service.md
---

# Spec: Make the omatheme runtime service resilient

## Design

Update the vendored `NobleDoodle/omarchroma` input from the old locked
revision `5d05f161c378f7daa43e4ec860ef335ac71f4272` to upstream `v3.0.0`,
commit `7048180b8c7261a6057d5218bd297f0d5ada24d0`, and refresh `flake.lock`.

That upstream revision already provides the required behavior:

- `hyprchroma --target=browsers` is a supported target, so the existing
  opt-in module option can remain unchanged.
- GTK and Qt icon synchronization checks both system and user icon paths. If a
  theme requests an unavailable icon set, it logs the condition, leaves the
  current icon setting unchanged, and exits successfully so the remaining
  palette synchronization and daemon startup continue.

Add compatibility coverage to the existing checks:

- assert the packaged CLI help advertises the browser target;
- exercise a missing icon theme in the desktop runtime fixture and assert the
  target still exits successfully while generating the other runtime files;
- retain the existing module assertion that browser synchronization is
  opt-in.

No Nixarchy service override or host-specific workaround is added. The module
continues to generate the browser command from the existing option, and the
upstream engine remains the single owner of target behavior.

## Alternatives rejected

- Removing the browser target from the module: it would hide a supported
  upstream capability and make the existing option misleading.
- Adding a custom wrapper that ignores browser or icon failures: it would
  duplicate upstream behavior and make status/error handling drift.
- Installing `Yaru-olive` on Razer: it would couple a generic runtime engine
  to one host's icon package and would not help users with other missing theme
  assets.
- Editing generated systemd units on Razer: it would be impermanent and
  violate the declarative ownership boundary.

## Risks

- The newer Omarchroma revision may change scripts or runtime dependencies;
  package and runtime checks must catch regressions.
- Browser synchronization remains profile-mutating and must stay disabled by
  default.
- Existing users may retain old generated state until the rebuilt user service
  restarts; deployment verification must check the active unit, not only the
  store path.

## Verification

- `nix flake check --all-systems --no-build` passes.
- Existing runtime, target, package dependency, module, and plugin checks pass.
- The built CLI accepts `--target=browsers`.
- A missing icon theme does not make GTK/Qt synchronization fail.
- Razer rebuilds from the fixed revision, `systemctl --user is-active
  hyprchromad.service` returns `active`, and a theme switch changes generated
  runtime files without a NixOS rebuild.
