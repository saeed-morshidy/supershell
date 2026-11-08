# Troubleshooting

Start with `supershell doctor` — it explains most problems and how to fix them.

| Symptom | Cause / fix |
|---|---|
| Boxes (□) instead of icons | Icon font missing: `supershell install fonts`, restart the terminal. Or `supershell icons plain`. Over SSH, `auto` already uses plain symbols. |
| Arabic letters separated / "choppy" | Font without Arabic glyphs. `supershell install fonts` (sets DejaVu Sans Mono in Ptyxis), or pick a monospace font with Arabic in the terminal preferences. |
| Arabic shown left-to-right | You're not in a VTE terminal (Ptyxis/GNOME Terminal) or you're inside tmux. See [arabic.md](arabic.md). |
| `A previous supershell run did not finish` | An install was interrupted. `supershell repair` rolls it back, then install again. |
| Prompt didn't change | Open a new terminal, or `exec bash`. Check `supershell mode` (classic?). Check `STARSHIP_CONFIG` isn't set to your own file. |
| Shell starts slowly | `supershell bench`. If `plus` is installed, that's ble.sh (~100 ms+). Check `supershell doctor` for duplicate initialisation in your `~/.bashrc`. |
| Something odd after install | Try `SUPERSHELL_DISABLE=1 bash`. If the problem is gone, it's supershell — please open an issue with the `doctor` output. |
| `git diff` looks different than in a tutorial | That's delta. `git --no-pager diff` shows plain output; `supershell remove git` disables it. |
| `bat` / `fd` not found but `batcat` / `fdfind` exist | `~/.local/bin` isn't on PATH yet: open a new terminal (Ubuntu adds it at login). |
| Checksum mismatch during install | The download was corrupted or tampered with; nothing was installed. Retry; if it persists, report it. |
| `Refusing to install an unverified download` | That tool has no pinned hash yet. Maintainers must run `scripts/update-manifest.sh`. Expert override: `SUPERSHELL_ALLOW_UNVERIFIED=1` (not recommended). |
| Neovim plugins missing | Plugins download on first start (needs network). Run `nvim` once while online. |
| Language server not working | In Neovim: `:checkhealth vim.lsp`, `:Mason`, or `:SupershellLspInstall`. |
| Need my old `~/.bashrc` back | `supershell restore --list`, then `supershell restore <id>`. |

Logs: `~/.local/state/supershell/install.log`.
