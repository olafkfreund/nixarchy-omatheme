# Theme target matrix

The runtime engine must not assume that every application supports an import.
Each target has one owner for structure and one owner for mutable theme data.

| Target | Structure owner | Runtime color owner | Runtime action | Fallback |
| --- | --- | --- | --- | --- |
| Omarchy shell/Hyprland | Omarchy | Omarchy | Native theme hook | None |
| Alacritty | Stylix or Omarchy wrapper | Omarchy theme file | Native template reload | Restart terminal |
| Kitty | Stylix or Omarchy wrapper | Omarchy theme file | Native template reload | Restart terminal |
| Foot | Stylix or Omarchy wrapper | Omarchy theme file | Native template reload | Restart terminal |
| Ghostty | Stylix or Omarchy wrapper | Omarchy theme file | Native template reload | Restart terminal |
| GTK 3/4 | Stylix wrapper or runtime engine | Runtime GTK CSS | Engine sync | Restart app |
| libadwaita | Runtime engine | Runtime GTK CSS/settings | Engine sync | Restart app |
| Qt/KDE | Stylix wrapper or runtime engine | Runtime KDE files | Engine sync | Restart app |
| GNOME settings | Stylix static defaults | Runtime gsettings | Engine sync | Re-login |
| Dark Reader | Browser policy/extension | Browser extension storage | Engine sync | Browser restart |
| Electron apps | App-specific wrapper/config | App-specific renderer | Target-specific | App restart |
| Flatpak apps | Declarative permissions | Runtime GTK/KDE files | Opt-in sync | App restart |
| GRUB/Plymouth/initrd | Stylix/NixOS | Stylix palette | Rebuild/reboot | Rebuild |
| Fonts/cursors/icons | Stylix/NixOS | Stylix packages | Rebuild | Rebuild |
| Unsupported app | Nix wrapper if safe | Target-specific | Report stale | Rebuild/manual |

## Ownership rules

1. A file has one writer at a time.
2. Stylix may generate a stable wrapper or import path, but not the mutable
   runtime file itself.
3. The engine writes only user-session files and uses atomic replacement.
4. A changed file is not counted as a live update until the application reloads
   it or is restarted safely.
5. Flatpak permissions are never changed unless the user explicitly enables the
   Flatpak target.
