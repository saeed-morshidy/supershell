# Known limitations (v0.1.0)

1. **Release checksums not pinned yet.** The manifest pins versions, but the
   SHA-256 values must be filled in by a maintainer with network access
   (`scripts/update-manifest.sh`) before the first release. Until then, tools come
   from Ubuntu's archive when it has a new enough version; GitHub releases are
   verified against the upstream checksum file where one exists, and refused
   otherwise (this currently blocks `plus` — ble.sh publishes no checksums — and
   any tool Ubuntu 26.04 doesn't package new enough without upstream checksums).
2. **Arabic:** cursor position in mixed Arabic/English lines can look wrong in the
   shell and in full-screen programs; tmux has no BiDi. Details in [arabic.md](arabic.md).
3. **ble.sh + Arabic** not verified yet (manual plan A22).
4. **Neovim treesitter parsers** are not installed: Bash, Python, Go, YAML,
   Dockerfile, Terraform use Vim's regex highlighting (fine, less precise);
   Lua, Markdown and Vimscript use Neovim's bundled treesitter.
5. **Language servers** are installed on demand inside Neovim (Mason), not pinned,
   and some need Node.js.
6. **Ptyxis font** is set through `gsettings`; other terminals must be set by hand.
7. **Ubuntu 24.04 / 25.10** are best-effort; other distributions are refused
   (`--force` to try).
8. **Root accounts** are refused by default (`--allow-root`).
9. `supershell update` pulls the git clone you installed from; if you deleted the
   clone, it re-applies the installed version only.
