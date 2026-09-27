---
status: approved
issue: 26
intent: intent/2026-09-27-26-nixos-runtime-integration.md
---

# Spec: Make the runtime theme engine declarative on NixOS

## Design

Extend the existing module architecture rather than introducing a second
installation path.

### NixOS and Nixarchy entry points

- Keep `nixosModules.default` as the explicit module for normal NixOS hosts.
- Keep `nixosModules.nixarchy` as the Nixarchy convenience module that enables
  the engine for the configured Nixarchy user.
- Keep the public option namespace
  `programs.nixarchyThemeEngine` and its existing target flags.
- Keep the single `enable` switch, with separate target options for users who
  want to disable a bridge. Separate engine/plugin switches are unnecessary
  until a real user needs them.

### Declarative runtime installation

The module installs the flake's existing `hyprchroma` and Omarchroma plugin
packages through Home Manager for the selected user. It provides:

- the `hyprchromad.service` user unit with the engine's absolute store path;
- Omarchy theme and font hooks;
- the plugin manifest and QML files under the user's Omarchy plugin directory;
- activation-time copies of Home Manager-managed configuration wrappers when a
  mutable runtime bridge must be written outside the Nix store.

The user service remains user-scoped because the engine watches the graphical
session and writes user configuration. It is ordered with the graphical
session, restarts on failure, and uses the existing least-privilege systemd
hardening. It must not use `DynamicUser`, because it needs the configured
user's session bus, home directory, and graphical environment.

### Stylix integration boundary

`stylix.mode = "auto"` remains the default:

- detect Stylix by checking whether the Stylix module has declared options;
- use runtime-only rendering when Stylix is absent;
- use the Stylix-aware mode when Stylix is present without requiring a Stylix
  package lookup or command at evaluation time;
- allow explicit `runtime` to ignore Stylix;
- reject explicit `stylix` mode when the Stylix module is not imported.

Stylix continues to own declarative application settings and generated
configuration. Hyprchroma owns only user-writable runtime palette files and
Omarchy hooks. Where an application supports imports, the runtime file is
linked from the declarative configuration instead of replacing the Nix store
path. When an application does not support imports, the module uses its
smallest safe user-owned wrapper or reports restart-required status.

### Runtime bridges

The first declarative release covers the bridges already implemented in the
repository:

- GTK, Qt/KDE, Dark Reader, Pear Desktop, and opt-in Flatpak;
- Kitty, Foot, and Ghostty runtime include files;
- Starship, Bash, Zsh, and Fish prompt refresh files;
- the verified VS Code Electron adapter, with unsupported Electron apps
  explicitly reported rather than modified speculatively.

The daemon performs the initial synchronization through `ExecStartPre`, then
watches Omarchy theme changes. The plugin reads the engine's state files and
reports synchronized, restart-required, unavailable, or unsupported status.

### Alacritty ownership fix

Alacritty must not be modified in place while its path is a Home Manager or
Stylix symlink. The activation step resolves the generated target, copies the
regular file into the user config path, and leaves runtime imports pointing to
user-owned files. The implementation must also verify ownership and write
permissions before a theme hook runs, and the Razer test must prove that the
previous permission warning no longer occurs.

## Alternatives rejected

- **Require Stylix:** rejected because Nixarchy's offline ISO does not install
  Stylix and must receive the same runtime behavior.
- **Run a system-wide daemon:** rejected because theme state, graphical
  session access, and application files are user-scoped.
- **Have Hyprchroma rewrite every Stylix-generated file:** rejected because it
  creates store ownership conflicts and causes rebuilds to overwrite runtime
  changes.
- **Install the plugin imperatively with `omarchy-plugin-enable`:** rejected
  as the primary path because it is not reproducible. Declarative activation
  must install and enable the plugin; the command remains a diagnostic/manual
  fallback only.
- **Create a second standalone theme configuration system:** rejected because
  it would duplicate the existing module, package, and target implementations.

## Risks

- Omarchy shell plugin registration may change across Omarchy releases; pin and
  test against the supported shell interface.
- Some applications can consume a changed file but cannot reload an existing
  window; status must say restart-required instead of claiming live sync.
- Stylix options and target names can change upstream; module evaluation tests
  must cover the detection and explicit-mode assertions.
- Home Manager activation may encounter existing user-owned files or broken
  symlinks; activation must remain non-destructive and fail clearly rather than
  deleting unrelated configuration.
- The service hardening may block a bridge that needs a session bus or a
  compositor socket; runtime tests must exercise the actual session on Razer.

## Verification

- `nix flake check --all-systems --no-build` evaluates Stylix-present,
  Stylix-free, explicit-mode, Nixarchy, service, plugin, and target cases.
- Build `.#hyprchroma` and `.#omarchroma-plugin` on x86_64-linux.
- Run the existing desktop, terminal/shell, Electron, and runtime target
  checks.
- Install the module on Razer through a temporary test configuration or test
  generation, then verify the user service, plugin registration, and state
  files after login.
- Switch between two Omarchy themes without `nixos-rebuild` and verify the
  configured target files and plugin status.
- Confirm Stylix-present and Stylix-free evaluation paths produce the same
  runtime service and target behavior.
- Confirm Alacritty activation leaves a writable user-owned config and no
  permission error appears during a theme switch.
- Run `git diff --check` and inspect the final generated service and activation
  commands before merging.
