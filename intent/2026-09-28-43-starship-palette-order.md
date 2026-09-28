---
status: draft
issue: 43
author: olafkfreund
---

# Intent: the generated starship config keeps its root keys

Follows `intent/2026-09-26-12-shell-runtime-targets.md`.

## Problem

`hyprchroma-shell` writes `~/.config/omarchy/runtime/starship.toml` as its
palette block followed by the user's base config (`render_starship()`, which
returns `block + base`). The block ends with the `[palettes.hyprchroma]`
table header. In TOML, every key after a table header belongs to that table,
so the base config's top-level keys (`add_newline`, `format`, and anything
else before its first table) become palette entries.

The result:

- Starship warns on every new shell:
  `Error in 'StarshipRoot' at 'palettes': … at 'add_newline': invalid type:
  boolean true, expected a string`.
- The captured root settings are lost, so the prompt falls back to
  starship's defaults for them.

It happens on every `omarchy theme set`. On 2026-09-28 it hit p620 (08:30) and
razer (after a theme switch there). Both were repaired by hand, and both break
again at the next switch.

`tests/runtime-targets.sh` did not catch it. It only greps the generated file
for `palette = "hyprchroma"` and `format = "$directory"`. Both strings are
present, just in the wrong table. Nothing parses the file as TOML or runs
starship against it.

## Proposed outcome

- The generated `starship.toml` keeps every root key of the base config at
  the root, selects `palette = "hyprchroma"`, and defines
  `[palettes.hyprchroma]` without capturing anything else.
- Starship loads the generated file with no warnings.
- A test fails if the palette table ever captures a root key again.

## Affected users and systems

- `pkgs/hyprchroma-shell` (`render_starship`) and `tests/runtime-targets.sh`.
- Downstream, every host that uses the shell runtime targets through nixarchy:
  p620 and razer today. p510 generates no runtime starship file.
- After merge: nixarchy's pin of this repo, then `olafkfreund/nixos_config`'s
  lock, then a deploy. Already-generated files are rewritten on the next
  theme switch or the next run of the generator.

## Constraints

- The user's base config is never edited. Only the generated runtime copy
  changes.
- It must stay idempotent: regenerating from a previously generated file
  (which carries the BEGIN/END markers) must not duplicate the block.
- There is no deploy to p510 without asking. (It isn't affected.)

## Open questions

1. **Where does the palette table go?** At the end of the file (simplest; a
   table at the end can't capture anything), or straight after the base
   config's root keys (it keeps the palette near the top when reading the
   file)? I recommend the end.
2. **Should the test run `starship print-config` / `starship prompt`** in the
   nix check, or parse with Python's `tomllib` and check the key placement?
   `tomllib` has no starship dependency and fails for the precise reason.
   I recommend tomllib, plus a starship run if starship is already in the
   test's inputs.
