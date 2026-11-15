# Theme target matrix

The runtime engine must not assume that every application supports an import.
Each target has one owner for structure and one owner for mutable theme data.

The matrix is the release contract: “Runtime action” describes what a live
theme switch can update, while “Fallback” describes the behavior when an
application cannot reload immediately. Targets marked unsupported are not
modified by the engine.

Palette capture and restore are runtime actions over the canonical user-owned
palette. They re-enter the normal synchronization path and do not change the
declarative owner of any target.

| Target | Structure owner | Runtime color owner | Runtime action | Fallback |
| --- | --- | --- | --- | --- |
| Omarchy shell/Hyprland | Omarchy | Omarchy | Native theme hook | None |
| Starship | Stylix or Home Manager | Hyprchroma runtime `starship.toml` | Prompt reads runtime config | None |
| Bash/Zsh/Fish | Home Manager shell config | Hyprchroma runtime exports | Prompt hook reloads colors | None |
| Alacritty | Home Manager/Stylix | Existing generated config or user-owned import | Bridge copies generated symlink to a regular file; external hook owns reload | Restart terminal / no Hyprchroma renderer |
| Kitty | Stylix or Omarchy wrapper | Hyprchroma runtime file | Remote color update when available | Reload/restart terminal |
| Foot | Stylix or Omarchy wrapper | Hyprchroma runtime file | New clients use updated file | Restart existing clients |
| Ghostty | Stylix or Omarchy wrapper | Hyprchroma runtime file | User-service reload when available | Restart terminal |
| GTK 3/4 | Stylix wrapper or runtime engine | Runtime GTK CSS | Engine sync | Restart app |
| libadwaita (GTK4) | Runtime engine | Runtime GTK CSS/settings | Engine sync, live without a restart | Restart app |
| Qt/KDE | Stylix wrapper or runtime engine | Runtime KDE files | Engine sync | Restart app |
| GNOME settings | Stylix static defaults | Runtime gsettings | Engine sync | Re-login |
| Dark Reader | Browser policy/extension | Browser extension storage | Engine sync | Browser restart |
| Additional browsers | Browser profiles | Omarchroma browser target | Deferred database sync | Browser exit / next launch |
| Thunderbird | Thunderbird profiles | Omarchroma Thunderbird target | Engine sync (`targets.thunderbird`, on by default) | Restart Thunderbird |
| VS Code | User settings JSON | Hyprchroma color customizations | Theme hook/settings reload | Reload window |
| Neovim | User config / Home Manager | Hyprchroma runtime `neovim-theme.lua` | In-editor watcher re-applies the theme's colorscheme, or `omarchy` | `:OmarchyThemeReload` / restart |
| Vim | User config / Home Manager | Hyprchroma runtime `vim-theme.vim` | In-editor watcher (needs `+timers`) applies `omarchy` | `:OmarchyThemeReload` / restart |
| Discord | Application-managed settings | None | Explicit unsupported status | No changes |
| Slack | Workspace/application preferences | None | Explicit unsupported status | No changes |
| Obsidian | Vault-scoped appearance | None | Explicit unsupported status | No changes |
| Other Electron apps | App-specific wrapper/config | App-specific renderer | Unsupported until verified | App restart |
| Flatpak apps | Declarative permissions | Runtime GTK/KDE files | Opt-in sync | App restart |
| GRUB/Plymouth/initrd | Stylix/NixOS | Stylix palette | Rebuild/reboot | Rebuild |
| Fonts/cursors/icons | Stylix/NixOS | Stylix packages | Rebuild | Rebuild |
| Omarchroma Icons | Not packaged ([#66](https://github.com/olafkfreund/nixarchy-omatheme/issues/66)) | None | `hyprchroma icons` reports it is unavailable | No changes |
| Unsupported app | Nix wrapper if safe | Target-specific | Report stale | Rebuild/manual |

The engine packages the Python `plyvel` dependency needed by Omarchroma's
browser database integration. The GTK target installs `adw-gtk3` and the
Qt/KDE target installs Breeze icons. Other GTK and Qt theme assets remain
host-level concerns.

The theme hook hands the sync to the `hyprchromad` service and returns at once.
Apps that need a restart appear in a stale-app list with a Dismiss button.
`restartMode` stays at upstream's default, `off`. The Arch setup installer and
uninstaller are not packaged; the NixOS module replaces them.

## `v0.1.0` verification

The first release verifies the module in both Stylix modes. Runtime checks
cover the Omarchy shell, GTK/Qt, shell prompts, Alacritty, Kitty, Foot,
Ghostty, VS Code, Vim, and Neovim paths; unsupported Discord, Slack, and
Obsidian integrations remain explicitly untouched.

## Ownership rules

1. A file has one writer at a time.
2. Stylix may generate a stable wrapper or import path, but not the mutable
   runtime file itself.
3. The engine writes only user-session files and uses atomic replacement.
4. A changed file is not counted as a live update until the application reloads
   it or is restarted safely.
5. Flatpak permissions are never changed unless the user explicitly enables the
   Flatpak target.
