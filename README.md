# supershell

**A modern, careful Bash environment for Ubuntu 26.04.** A clean prompt, fuzzy
search, smart navigation, readable Git diffs, a ready-to-use Neovim and DevOps
awareness — while your shell stays plain Bash and every standard command keeps
working exactly as on any other Ubuntu machine or server.

[العربية](README.ar.md) · [Architecture](docs/architecture.md) · [Why these tools](docs/technology-selection.md) · [Arabic support](docs/arabic.md)

```
 user  ~/projects/api   main !1?1   k8s-dev (payments)   ♥ 21:48
❯ _
```

## Principles

- **Bash stays Bash.** `ls`, `cat`, `grep`, `find`, `cd`, `vi` are never redefined.
  New tools have their own names (`ll`, `bat`, `rg`, `z`). Scripts, `scp` and
  `rsync` are unaffected because nothing runs in non-interactive shells.
- **One line in `~/.bashrc`.** A clearly marked block, backed up first, removed
  byte-for-byte on uninstall.
- **Fast.** No framework, no daemons, no network at start-up; tool `init` output is
  cached. `supershell bench` shows the real cost on your machine.
- **Safe to try.** Every run is a transaction: if anything fails or you press
  Ctrl-C, it rolls back. `supershell mode classic` gives you stock Bash instantly.
- **Arabic is tested,** and its limits are documented honestly.

## Install

```bash
git clone https://github.com/saeed-morshidy/supershell.git
cd supershell
./supershell install --dry-run   # see exactly what would be installed, and from where
./supershell install             # the default modules
```

The first install asks two questions:

- **prompt** — *supershell-theme* (default): supershell's own theme — a colour bar
  across the full terminal width, square ends, the clock at the right — or *starship*:
  the pastel-powerline [preset](https://starship.rs/presets/) exactly as published.
  `--custom` / `--default`; back to the default any time with `supershell theme reset`.
- **terminal font** — DejaVu Sans Mono (default), Cascadia Code, JetBrains Mono, Fira Code,
  IBM Plex Mono or Ubuntu Sans Mono, installed from Ubuntu's archive. `--font=NAME`;
  change later with `supershell font <name>`.

`--yes` takes the defaults.

Then open a new terminal. `supershell doctor` checks everything.

Requirements: Ubuntu 26.04 LTS (24.04 and 25.10 best-effort), x86_64 or aarch64,
Bash 5.1+, `sudo` for apt packages. Run it as your normal user.

## Modules

| Module | Default | What you get |
|---|---|---|
| `core` | ✓ | [Starship](https://starship.rs) prompt, `fzf` (Ctrl-R / Ctrl-T / Alt-C), `zoxide` (`z`), `eza` (`ll`, `lt`), `bat`, `fd`, `rg` |
| `git` | ✓ | [delta](https://github.com/dandavison/delta) for readable diffs (one include line in `~/.gitconfig`) |
| `editor` | ✓ | Neovim 0.12 profile: LSP, completion, fuzzy find, git signs, file browser |
| `fonts` | ✓ | terminal font of your choice from Ubuntu's archive (DejaVu Sans Mono, Cascadia Code, JetBrains Mono, Fira Code, IBM Plex Mono, Ubuntu Sans Mono — asked on the first install), Arabic always in fixed-width cells, Nerd Font **icons as a fallback** (no patched fonts) |
| `devops` | ✓ | k8s context / docker context / terraform workspace in the prompt; tab completion for installed tools |
| `lazygit` | | full-screen Git UI |
| `helix` | | Helix (`hx`), a zero-config modal editor, as a second profile |
| `plus` | ✓ | suggestions as you type + syntax colours (ble.sh, from Ubuntu's package) + Atuin (local history search) — adds ~100 ms start-up; `supershell remove plus` for the fastest shell |
| `tmux` | | tmux with sensible defaults (never auto-started) |

```bash
supershell install lazygit tmux      # add modules
supershell remove helix              # remove one
supershell list                      # what's installed
```

## Everyday commands

| Command | |
|---|---|
| `supershell mode classic` / `modern` | plain Ubuntu Bash (e.g. while following a tutorial) / the supershell experience |
| `supershell devops on` / `off` | DevOps info in the prompt + completions |
| `supershell devops aliases on` | short aliases `k`, `d`, `dc`, `tf` (off by default — learn the full commands first) |
| `supershell icons auto\|nerd\|plain` | icon style (`auto` uses plain symbols over SSH) |
| `supershell theme` | supershell-theme (the default prompt): `theme colors <name>` (supershell, pastel, tokyo-night, catppuccin, gruvbox, nord, dracula, rose-pine, kanagawa), `theme root-colors <name>` (default: a red `supershell-root`), `theme reset` |
| `supershell prompt [<style>]` | other styles: `pastel-powerline`, `tokyo-night`, `gruvbox-rainbow`, `catppuccin-mocha` / `-macchiato` / `-frappe` / `-latte`, `simple` |
| `supershell prompt custom on\|off` | supershell's prompt (full width, square ends — the default) or the starship preset as published; `prompt cap on` = the preset's rounded start |
| `supershell prompt edit` | your own prompt tweaks (`~/.config/supershell/prompt.toml`), kept across styles and updates |
| `supershell font [<name>]` | terminal font; Ptyxis updates right away |
| `supershell root on\|off` | the same prompt in root shells (`su -`, `sudo -i`) — root-owned copies, prompt only, asks for sudo once |
| `supershell keys` | shortcut cheat sheet |
| `supershell doctor` | health check |
| `supershell bench` | start-up time and memory, with and without supershell |
| `supershell update` | update supershell and the tools |
| `supershell restore` | put back any file from a backup |
| `supershell uninstall` | remove everything (your files are kept) |

Need the original command while an alias exists? `\ls`, `command ls`.
Disable supershell for one shell: `SUPERSHELL_DISABLE=1 bash`.

## Keyboard shortcuts (modern mode)

| Keys | Action |
|---|---|
| `Ctrl-R` | fuzzy search command history |
| `Ctrl-T` | insert a file path (with preview) |
| `Alt-C` | jump into a sub-folder |
| `z name` / `zi` | jump to a frequent folder / pick one interactively |
| `vim **<Tab>` | fuzzy completion for any command |

Editor shortcuts: [docs/editor.md](docs/editor.md).

## Documentation

- [Architecture](docs/architecture.md) · [Technology selection report](docs/technology-selection.md)
- [Configuration](docs/configuration.md) · [Editor](docs/editor.md)
- [Arabic support](docs/arabic.md) · [Arabic manual test plan](docs/arabic-test-plan.md)
- [Troubleshooting](docs/troubleshooting.md) · [Known limitations](docs/known-limitations.md)
- [Testing](docs/testing.md) · Reports: [tests](docs/reports/test-results.md), [Arabic](docs/reports/arabic-compatibility.md), [performance](docs/reports/performance.md), [security & dependencies](docs/reports/security-dependencies.md)

## Contributing

Open source under the [MIT License](LICENSE). Everyone can fork and propose changes;
merging needs **3 maintainer approvals** — see [CONTRIBUTING.md](CONTRIBUTING.md)
and [GOVERNANCE.md](GOVERNANCE.md).

## Acknowledgements

Ideas (not code) were learned from [Omakub](https://github.com/basecamp/omakub)
(a menu-driven setup with update/uninstall) and
[shell-bling-ubuntu](https://github.com/hiAndrewQuinn/shell-bling-ubuntu) (pinned
versions, test matrix), and from discussions in the Atuin, ble.sh and Neovim
communities. Thanks to egmont for the BiDi work in VTE that makes Arabic usable in
Ubuntu's terminal.
