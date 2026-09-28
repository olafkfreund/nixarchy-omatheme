---
status: approved
issue: 43
intent: intent/2026-09-28-43-starship-palette-order.md
---

# Spec: the generated starship config keeps its root keys

The intent was approved on 2026-09-28 with the recommended answers:

| # | Question | Decision |
| --- | --- | --- |
| 1 | Where the palette table goes | At the **end** of the generated file |
| 2 | How the test checks it | Python's `tomllib`, checking where keys land |

There is no real starship run for decision 2: starship is only a stub
(`exit 0`) in `tests/runtime-targets.sh`. `python3` is already in the check's
`nativeBuildInputs`.

## Design

### 1. `pkgs/hyprchroma-shell`: `render_starship()` emits two marked regions

The palette *selection* is a root key and must come before any table. The
palette *definition* is a table and must come after everything else:

```python
head = [BEGIN, 'palette = "hyprchroma"', END]
table = [BEGIN, "[palettes.hyprchroma]"]
table.extend(f"{key} = \"{value}\"" for key, value in palette.items())
table.append(END)
return "\n".join(head) + "\n\n" + base.strip() + "\n\n" + "\n".join(table) + "\n"
```

- The existing stripping stays as it is.
  `re.sub(rf"(?ms)^{BEGIN}.*?^{END}\n?", "", base)` is non-greedy and
  substitutes every match, so a base that already carries both regions (for
  example, a runtime copy used as a base) loses both, and nothing is
  duplicated.
- The existing `^palette\s*=` removal stays, so a user's own palette
  selection doesn't fight ours. User palette *tables* (`[palettes.user]`)
  are kept.
- Nothing else in the file changes: the shell and fish themes and the status
  JSON are untouched.

### 2. `tests/runtime-targets.sh`: a realistic base and a structural check

The base fixture gains what real configs have, and what the old fixture
lacked (which is why the bug passed):

```toml
add_newline = true
format = "$directory"
palette = "user"

[git_status]
style = "red"

[palettes.user]
color_fg0 = "#000000"
```

After the first `run_renderers`, a `python3` block parses the generated file
with `tomllib` and asserts:

- `palette == "hyprchroma"`, `add_newline is True`, `format == "$directory"`
  (the root keys survived, with their types)
- `palettes.hyprchroma` has exactly the 11 `color_*` keys, all strings (it
  captured nothing)
- `git_status.style == "red"` and `palettes.user` is still present (the
  user's tables are intact)

After that, the renderer runs **again with the same palette**, and the file
must be byte-identical with exactly two `BEGIN` markers (idempotent, no
duplication). The existing palette-one / palette-two change check stays.

The existing `grep -Fq` lines stay: they are cheap and still true.

### 3. Rollout (outside this repo)

1. Merge here.
2. Bump nixarchy's `nixarchy-omatheme` pin (a nixarchy PR).
3. Bump `olafkfreund/nixos_config`'s lock and deploy p620 and razer
   (bus-announced). p510 generates no runtime starship file.
4. Regenerate the runtime file on each host. The fixed generator only rewrites
   it when it runs, so re-run it once: re-apply the current theme with
   `omarchy theme set <current>`, or start the generator unit directly.

## Alternatives rejected

- **Insert the table right after the base's root keys:** it needs its own
  TOML-aware split of the base (where do the root keys end?) for no gain.
  A table at the end is correct by construction.
- **Rewrite with a TOML library (`tomllib` + a writer):** the standard library
  has no writer, and a third-party one would reorder and reformat the user's
  file. The text approach preserves their comments and layout.
- **Add real `starship` to the test inputs:** a larger closure for the check,
  and `tomllib` already fails for exactly this bug. It can be added later if
  starship's own validation is wanted.

## Risks

- **A base with no trailing newline, or ending in a comment** (generator):
  `base.strip()` plus explicit blank lines, and the tomllib test covers a
  realistic fixture.
- **Existing runtime files stay broken until regenerated** (p620, razer):
  rollout step 4. The hand repairs from 2026-09-28 hold until then.
- **The old stripping removes only one region per match** (generator):
  `re.sub` replaces every non-overlapping match, and the idempotency test
  proves nothing is duplicated.

## Verification

1. **Red first:** apply only the test change and run
   `nix build .#checks.x86_64-linux.<runtime-targets check>`. It must
   **fail** on the tomllib assertion about the captured root keys. This
   proves the test catches the bug.
2. **Green:** with the generator fix, the same check passes, and
   `nix flake check` passes overall.
3. **Real config:** run the fixed `hyprchroma-shell` against p620's real
   `starship.base.toml` in a temporary `XDG_CONFIG_HOME`, then
   `STARSHIP_CONFIG=<generated> STARSHIP_LOG=warn starship prompt` inside a
   git repo. Expect 0 warnings, and `palette = hyprchroma` in the tomllib
   parse.
