# Architecture

## Big picture

```
 ~/.bashrc  ──(one marked block)──►  ~/.local/share/supershell/app/shell/init.bash
                                          │  interactive shells only, prints nothing
                                          ├─ reads ~/.config/supershell/config  (no fork)
                                          ├─ mode=classic? → stop here (stock Bash)
                                          ├─ plus/pre.bash   ble.sh, detached   (if installed)
                                          ├─ core/shell.bash   starship · zoxide · fzf · aliases
                                          ├─ git, lazygit, editor, helix, devops, tmux shell.bash
                                          └─ plus/shell.bash  atuin · ble-attach (last)

 supershell (CLI) ── lib/ ── modules/<name>/module.sh ── manifest/tools.ini
```

The **CLI** changes the system; **init.bash** only reads. They never share state
except through files in `~/.config/supershell` and `~/.local/state/supershell`.

## Where things live

| Path | Content | Owner |
|---|---|---|
| `~/.local/share/supershell/app` | installed copy of the repo (the clone can be deleted) | supershell |
| `~/.local/share/supershell/opt/<tool>/<version>` | release binaries | supershell |
| `~/.local/bin/<tool>` | symlinks to the above (never overwrites existing files) | supershell |
| `~/.config/supershell/config` | settings (`supershell config list`) | user |
| `~/.config/supershell/starship-{nerd,plain}.toml` | rendered prompt configs | supershell |
| `~/.config/supershell-nvim/` | Neovim profile (`NVIM_APPNAME=supershell-nvim`) | shared* |
| `~/.local/state/supershell/` | installed modules, tools, managed configs, backups, journal, log | supershell |
| `~/.cache/supershell/init/` | cached `starship/zoxide/fzf/atuin init` output | supershell |

\* Managed config files are recorded with their SHA-256. If you edit one,
supershell never overwrites or deletes it; its own version goes next to it as
`<file>.supershell`.

## Install = transaction

1. Preflight: OS/arch/Bash version, not root, module names valid.
2. `journal_begin` writes `~/.local/state/supershell/journal`.
3. Every change is journaled **before** it happens: file backed up (`backup`),
   file created (`absent`), directory created (`created`), module marked
   (`module`), apt package installed (`apt`), app replaced (`restore_app`).
4. Success → journal deleted. Error or Ctrl-C → journal replayed backwards.
5. Power loss / `kill -9` → the journal survives; the next run refuses to start
   and `supershell repair` replays it.

Only the run that created a journal may roll it back automatically.

## Tool installation

`install_tool <name>` in `lib/tools.sh`:

1. apt package already installed and ≥ `apt_min` → use it.
2. apt candidate ≥ `apt_min` → `sudo apt-get install`.
3. Otherwise the pinned GitHub release from `manifest/tools.ini`, verified by
   pinned SHA-256 → else upstream checksum file (warning) → else refused.

Ubuntu's renamed binaries get friendly links (`batcat` → `bat`, `fdfind` → `fd`).

## Start-up performance

- `init.bash` reads settings with `read` and finds commands by walking `$PATH`
  in Bash — no subprocesses.
- `starship init`, `zoxide init`, `fzf --bash`, `atuin init` run **once**; output is
  cached and regenerated only when the binary is newer than the cache.
- DevOps completions are written as files that bash-completion loads only when
  you press Tab on that command.
- Starship modules that run external commands (language versions) are off unless
  devops is on, and Python shows only an active virtualenv.

## Modes and icons

- `mode=classic` returns from `init.bash` immediately: stock Bash.
- Icons: `nerd` only when the icon font is installed **and** the session isn't SSH
  or the Linux console; otherwise `plain` (common Unicode only).
