# Security & dependency report — v0.1.0

## Dependencies

| Tool | Module | Version pinned | Preferred source | Fallback source | Upstream checksums | SHA-256 pinned |
|---|---|---|---|---|---|---|
| starship | core | 1.27.0 | apt ≥ 1.27 | GitHub release | ✅ pinned (source: upstream `.sha256` **and** GitHub asset digest) | ✅ |
| fzf | core | 0.62.0 | apt ≥ 0.48 | GitHub release | ✅ pinned (source: release `SHA-256.txt`) | ✅ |
| zoxide | core | 0.9.8 | apt ≥ 0.9 (26.04 has 0.9.8) | GitHub release | no | ⏳ |
| eza | core | 0.21.0 | apt ≥ 0.18 | GitHub release | no | ⏳ |
| bat | core | 0.25.0 | apt ≥ 0.24 | GitHub release | no | ⏳ |
| fd | core | 10.2.0 | apt ≥ 9.0 | GitHub release | no | ⏳ |
| ripgrep | core | 14.1.1 | apt ≥ 14.0 | GitHub release | yes | ⏳ |
| delta | git | 0.18.2 | apt ≥ 0.16 | GitHub release | no | ⏳ |
| lazygit | lazygit | 0.50.0 | apt ≥ 0.40 | GitHub release | yes | ⏳ |
| neovim | editor | 0.12.6 | apt ≥ 0.12 | GitHub release | ✅ pinned (source: GitHub asset digest; `shasum.txt` is no longer published) | ✅ |
| helix | helix | 25.07.1 | — | GitHub release | no | ⏳ |
| atuin | plus | 18.15.2 | apt ≥ 18.4 | GitHub release | yes | ⏳ |
| ble.sh | plus | 0.4.0-devel3 | — | GitHub release | no | ⏳ |
| Symbols Nerd Font | fonts | 3.4.0 | — | GitHub release | yes | ⏳ |
| tmux | tmux | system | apt ≥ 3.3 | — | apt-signed | n/a |
| fonts-dejavu-core, wl-clipboard, git | fonts/editor | system | apt | — | apt-signed | n/a |

Neovim plugins (installed by Neovim's `vim.pack`, versions recorded in
`nvim-pack-lock.json`): nvim-lspconfig, mason.nvim, mini.nvim (`stable` branch),
fzf-lua, gitsigns.nvim. Language servers: installed on request via Mason.

**Release blocker:** the ⏳ column must be filled by a maintainer with
`scripts/update-manifest.sh` (this build environment had no network access to
GitHub). The versions above were chosen from release information available at
build time and must be re-checked with `scripts/update-manifest.sh --latest`.

## Controls

| Risk | Control | Tested |
|---|---|---|
| Tampered/corrupted download | SHA-256 pinned → else upstream sums → else refused; file deleted on mismatch | ✅ unit |
| Remote script execution | no `curl \| sh`; archives are extracted, binaries linked | by review |
| Clobbering user files | backups; `install_config` keeps user-edited files; `link_bin` never replaces non-supershell files | ✅ unit + integration |
| Partial installs | transaction journal, rollback on error/Ctrl-C, `repair` after kill -9 | ✅ integration |
| Deleting outside our dirs | `safe_rm` refuses any path outside supershell's directories | ✅ unit |
| Privilege | refuses to run as root; `sudo` only for apt | ✅ integration |
| Secrets in history (Atuin) | `secrets_filter = true`, leading-space commands not saved, sync off | config review |
| Telemetry / network at start-up | none; Atuin `update_check=false`, `auto_sync=false` | ✅ (no network calls in start-up tests) |
| Supply chain of the project itself | 3 maintainer approvals, required CI, code owners for manifest/CI | `scripts/setup-github.sh` |

## Static analysis

ShellCheck runs in CI (`lint` job). It was **not run** in the build environment
(not installable without network); `bash -n` syntax checks passed for every file.
