# Performance report — v0.1.0

## What was measured here

Environment: Ubuntu 24.04 container, bash 5.2. Real tools were **not** available
(no network), so the managed tools are stubs. These numbers therefore measure
**supershell's own code** (reading settings, resolving icons, sourcing modules,
loading cached init files):

| Measurement | Without supershell | With supershell | Overhead | Budget |
|---|---|---|---|---|
| Interactive start-up (`bash -i -c exit`, mean of 20) | 4 ms | 5 ms | 1 ms | < 40 ms ✅ |
| Memory per shell (RSS) | 4036 KB | 4052 KB | 16 KB | < 3 MB ✅ |
| Background processes after start-up | — | 0 | — | 0 ✅ |
| Tools executed on a cached start-up | — | 0 | — | 0 ✅ |

## What the real cost will be (to be measured)

With real tools the remaining per-shell cost is sourcing the cached Starship,
zoxide and fzf init scripts, plus Starship rendering each prompt (it runs on
every prompt, typically a few ms; more in very large Git repos). The `plus`
module (ble.sh) adds roughly 100 ms+ because ble.sh is a large pure-Bash program.

Run on the target laptop and paste the output here:

```bash
supershell bench 20
```

| Laptop (Ubuntu 26.04.1, x86_64, bash 5.3) | Start-up | Memory |
|---|---|---|
| Before install (recorded automatically on first install) | 31 ms | baseline |
| supershell, modules core + git + devops (real tools) | 57 ms (+26 ms) | unchanged |
| All five default modules (core, git, devops, editor, fonts), `supershell bench 20` | 12 ms → 23 ms (+11 ms) | 4372 KB → 4324 KB (no increase) |

Note: the two laptop runs differ in absolute numbers (31/57 ms vs 12/23 ms); the
second run was on a warm system. Compare overheads within one run, never across
runs. `editor` and `fonts` add nothing to start-up (they only install files).
| supershell + plus | ⏳ | ⏳ |

CI's `e2e (ubuntu-26.04)` job appends `supershell bench` output to its results artifact.

## Design choices that keep it fast

- No framework; one small init file; settings read without subprocesses.
- `init` outputs cached, regenerated only when a binary changes.
- DevOps completions load lazily (on Tab), not at start-up.
- Starship: explicit module list; toolchain modules off unless devops is on.
- No daemons (Atuin runs without its daemon), no network at start-up.

## Prompt drawing time (laptop, in a git repo, mean of 20)

| Prompt style | Time per prompt |
|---|---|
| `simple` (nerd icons) | 1 ms |
| `gruvbox-rainbow` | 8 ms |
| `tokyo-night` (default), starship 1.27.0 | 8 ms |
| `catppuccin-mocha`, starship 1.27.0 | 8 ms |

Start-up with `gruvbox-rainbow`: 12 ms → 24 ms (+12 ms); with `tokyo-night` and starship 1.27.0: +10 ms. Same as the simple style.
The preset shows language versions (Node, Rust, Go, PHP, Java, Python…) only inside
projects of that language; there it runs the tool's `--version` per prompt.
