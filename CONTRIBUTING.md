# Contributing

Thanks for helping! A few rules keep supershell safe and fast.

## Ground rules

1. **Never redefine a standard command.** `ls`, `cat`, `grep`, `find`, `cd`, `vi`
   … must behave exactly like stock Ubuntu. New tools get their own names.
2. **Interactive start-up prints nothing** and starts no background processes.
3. **No network at shell start-up.** Expensive `init` output is cached
   (`__ss_eval_cached` in `shell/init.bash`).
4. **Never overwrite a user's file.** Use `install_config` / `journal_track_file`;
   both back up and are rolled back on failure.
5. **Downloads are pinned and verified.** Add tools to `manifest/tools.ini`, then
   run `scripts/update-manifest.sh <tool>`.
6. Bash 5.1+, `set -Eeuo pipefail` in the CLI. Mind the classic traps: a function
   whose last command is `[[ … ]] && x` returns 1; `local a=$1 b=$a` doesn't work.

## Layout

| Path | What |
|---|---|
| `supershell` | the CLI (commands, transaction handling) |
| `lib/` | shared code: paths, OS detection, state, backups/journal, bashrc block, tools |
| `modules/<name>/module.sh` | install / remove / doctor for one module |
| `modules/<name>/shell.bash` | what the module does in an interactive shell |
| `shell/init.bash` | the single file `~/.bashrc` sources |
| `config/` | configuration files that get installed |
| `manifest/tools.ini` | versions, URLs, SHA-256 |
| `tests/` | dependency-free test suite (`tests/run.sh`) |

## Adding a module

Create `modules/<name>/module.sh` with `MOD_DESC`, `MOD_DEFAULT`, `MOD_TOOLS`,
`MOD_DEPS` and the functions `mod_install`, `mod_remove`, `mod_doctor` (and
optionally `mod_apply`). Add it to `SS_MODULE_ORDER` in `lib/modules.sh` and to the
loop in `shell/init.bash` if it has a `shell.bash`. Add tests.

## Tests

```bash
tests/run.sh                 # everything (≈2–3 minutes, no network, no root)
tests/run.sh unit            # one group: unit | integration | arabic | perf
tests/run.sh -k uninstall    # tests whose name matches
shellcheck -x supershell lib/*.sh modules/*/*.sh
```

`tests/e2e/run.sh` installs real packages; CI runs it in an `ubuntu:26.04` container.
Don't run it on your own machine.

## Review

Every PR needs **3 maintainer approvals** — see [GOVERNANCE.md](GOVERNANCE.md).
Use the PR checklist.
