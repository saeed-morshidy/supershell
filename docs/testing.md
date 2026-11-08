# Testing

## Automated suite

```bash
tests/run.sh              # all groups — no network, no root, no changes to your system
tests/run.sh integration  # one group
tests/run.sh -k arabic    # by name
```

The harness (`tests/lib/harness.sh`) gives every test a fresh temporary `HOME` and
puts stubs first on `PATH`: `apt-get`, `apt-cache`, `dpkg-query`, `sudo`, `curl`,
`gsettings`, `fc-list`, and one fake program that impersonates every managed tool.
The real `bash`, `git`, `tmux` and `rg` are used. Results go to
`tests/results/latest.md`.

| Group | Covers |
|---|---|
| `unit` | OS/arch detection and support policy, `.bashrc` block (idempotent, byte-exact removal, no trailing newline, symlinked bashrc), backups/restore, journal rollback, safe deletion, settings validation, manifest, checksum verification (pinned, upstream file, mismatch, none), apt-vs-release choice, Ubuntu binary names |
| `integration` | fresh install, selected modules, dependencies, repeated install, apt failure → rollback, failure in a later module → rollback, `kill -9` mid-install → `repair`, offline, uninstall (byte-exact `.bashrc`, git config, fonts, Ptyxis font restored), user-owned packages kept, reinstall, user-edited configs never overwritten, existing git pager respected, restore, doctor, dry-run, root guard, unknown module; interactive shells: silent start-up, non-interactive shells untouched, standard commands unchanged, user aliases/functions kept, classic mode, `SUPERSHELL_DISABLE`, init caching, double sourcing, devops completions/aliases/prompt, icons vs SSH, editor environment, delta fallback |
| `arabic` | Arabic filenames, Tab completion (in tmux), cursor movement and insertion in a mixed line, history, punctuation/diacritics/digits, `rg` search, Arabic directory prompt, non-UTF-8 detection, plain icons, Neovim round-trip (needs real Neovim) |
| `perf` | framework start-up overhead and memory budget, no background processes, `supershell bench` |

## CI (GitHub Actions)

- `lint`: ShellCheck + `bash -n`.
- `tests (ubuntu-24.04)`, `tests (ubuntu-26.04)`: the suite in containers, as a normal user.
- `e2e (ubuntu-26.04)`: `tests/e2e/run.sh` — real apt packages and downloads, doctor,
  Neovim profile and Arabic round-trip, bench, uninstall (byte-exact `.bashrc`), reinstall.

All four are required checks for merging.

## Manual

Visual Arabic behaviour: [arabic-test-plan.md](arabic-test-plan.md). Real start-up
numbers: `supershell bench` on the target laptop.

## Honesty rule

A test that can't run in an environment is reported as **skipped** with the reason,
never as passed. Reports in `docs/reports/` say where each result came from.
