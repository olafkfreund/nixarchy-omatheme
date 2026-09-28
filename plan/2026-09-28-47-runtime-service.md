---
status: draft
issue: 47
spec: spec/2026-09-28-47-runtime-service.md
---

# Plan: Make the omatheme runtime service resilient

Refresh the vendored Omarchroma input to `v3.0.0` at
`7048180b8c7261a6057d5218bd297f0d5ada24d0`. That upstream revision supports
the browser target already emitted by the module and treats missing icon themes
as non-fatal. Keep the existing module options and service ownership intact.

## Steps

1. `flake.lock`: update the `omarchroma` input to the approved commit → verify
   the locked revision and hash are reproducible.
2. `flake.nix`/package checks: add the smallest assertion that the packaged
   `hyprchroma` help exposes `--target=browsers` → verify the CLI compatibility
   is tested from the built package.
3. `tests/desktop-runtime.sh`: add a missing-icon-theme fixture → verify GTK
   and Qt synchronization exit successfully and still write runtime files.
4. Run the omatheme flake checks → verify module, target, package dependency,
   plugin, and runtime tests pass.
5. Build the fixed revision and deploy it to Razer using an immutable input
   override → verify the Razer config directory and lockfile remain unchanged.
6. Validate Razer runtime behavior → verify `hyprchromad.service` is active,
   the browser target is accepted, missing `Yaru-olive` is non-fatal, and a
   theme switch changes runtime output without a rebuild.
7. Review, commit, push, and open a PR closing #47 → verify CI passes before
   merge.

## Tests

- `nix flake check --all-systems --no-build`
- The focused runtime target and desktop runtime checks.
- `nix build .#checks.x86_64-linux.runtime-targets`
- `nix build .#checks.x86_64-linux.desktop-runtime`
- Razer `systemctl --user is-active hyprchromad.service`.
- Razer `hyprchroma --target=browsers --set-enabled=false --quiet`.

Expected result: all checks pass, the daemon remains active with Razer's
installed icon set, and runtime theme switching works without a rebuild.

## Rollback

Restore the previous Omarchroma lock entry at
`5d05f161c378f7daa43e4ec860ef335ac71f4272` and redeploy the prior known-good
generation. On Razer, use `sudo nixos-rebuild --rollback switch` if activation
itself is unhealthy.
