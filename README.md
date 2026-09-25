# nixarchy-omatheme

NixOS packaging and integration for an Omarchy-compatible runtime theme engine.

The project keeps Omarchy's palette as the runtime source of truth and leaves
Stylix responsible for declarative and rebuild-time surfaces.

## Development

```sh
nix flake check
nix build
```
