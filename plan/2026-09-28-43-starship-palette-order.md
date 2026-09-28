---
status: draft
issue: 43
spec: spec/2026-09-28-43-starship-palette-order.md
---

# Plan: the generated starship config keeps its root keys

Branch `fix/43-starship-palette-order`, in a worktree of
`/mnt/data/Source-home/GitHub/nixarchy-omatheme`. The local checkout is not
touched.

## Approved decisions

These are carried over from the spec.

**D1. The palette table goes at the end.** In `pkgs/hyprchroma-shell`,
`render_starship()` returns:

```python
head = [BEGIN, 'palette = "hyprchroma"', END]
table = [BEGIN, "[palettes.hyprchroma]"]
table.extend(f"{key} = \"{value}\"" for key, value in palette.items())
table.append(END)
return "\n".join(head) + "\n\n" + base.strip() + "\n\n" + "\n".join(table) + "\n"
```

The existing `BEGIN`…`END` stripping and `^palette\s*=` removal stay as they
are.

**D2. The test checks structure with `tomllib`.** In
`tests/runtime-targets.sh`:

- The base fixture becomes `add_newline = true`, `format = "$directory"`,
  `palette = "user"`, then `[git_status]` with `style = "red"`, then
  `[palettes.user]` with `color_fg0 = "#000000"`.
- After the first `run_renderers`, a `python3` block asserts:
  - `palette == "hyprchroma"`
  - `add_newline is True`
  - `format == "$directory"`
  - `palettes.hyprchroma` has exactly the 11 `color_*` keys, all strings
  - `git_status.style == "red"`
  - `palettes.user` exists
- A second run with the same palette must produce a byte-identical file with
  exactly two `BEGIN` markers.
- The existing `grep -Fq` lines and the palette-one versus palette-two change
  check stay.

**D3. There is no real starship in the check.** It's a stub there.

**D4. Rollout, outside this repo:** nixarchy pin bump, then the
nixos_config lock, then deploy p620 and razer (bus-announced, and verify the
bar has content afterwards), then regenerate each host's runtime file once.

## Steps

1. **Test first** (D2) → verify:
   `nix build .#checks.x86_64-linux.runtime` **fails** on the tomllib
   assertion that the root keys are at the root.
2. **Generator fix** (D1) → verify: the same check passes.
3. **Whole suite** → verify: `nix flake check` passes.
4. **Real config** → verify: run the built `hyprchroma-shell` with a
   temporary `XDG_CONFIG_HOME` holding p620's real `starship.base.toml`
   (copied). Then `STARSHIP_CONFIG=<generated> STARSHIP_LOG=warn starship
   prompt` inside a git repo must give 0 warnings, and tomllib must show
   `add_newline` at the root.
5. **Commit** as `fix(shell): keep starship root keys out of the hyprchroma
   palette table (#43)`, push, and open a PR linking the intent, spec and
   plan.
6. **Merge** on green CI (squash, pinned to the head commit).
7. **Rollout** (D4): a nixarchy PR bumping `nixarchy-omatheme`, then
   nixos_config's lock, then deploy. Each step is announced on the bus.

## Tests

| # | Command | Expected |
| --- | --- | --- |
| T1 | step 1 check, test change only | fails, naming the captured root key |
| T2 | step 2 check | passes |
| T3 | `nix flake check` | passes |
| T4 | step 4 real-config run | 0 warnings, `add_newline` at the root |

## Rollback

- **Before merge:** close the PR.
- **After merge:** `git revert` the step-5 commit. Hosts keep whatever runtime
  file they have until the generator runs again.
