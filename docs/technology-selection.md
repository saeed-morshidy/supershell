# Technology selection report

Researched November 2026 for Ubuntu 26.04 LTS. Each choice was weighed on features,
maintenance, adoption, Ubuntu/Bash compatibility, resource use, security,
installation, upgrade/removal and long-term maintainability.

## Shell: Bash (kept)

zsh and fish have native autosuggestions, but Bash is what every server and
tutorial uses, which matters most to someone learning Linux and DevOps. The two
things Bash lacks (syntax highlighting, suggestions) are covered by the optional
`plus` module.

## Prompt: Starship

| | Starship | oh-my-bash / bash-it | hand-written PS1 |
|---|---|---|---|
| Speed | fast (Rust), only modules in `format` run | 100–300 ms start-up with plugins | fastest |
| Git/k8s/venv | built-in | via plugins | write yourself |
| Maintenance | very active, huge adoption | slower | none |
| Removal | one binary + one file | framework tree | — |

Frameworks like oh-my-bash bundle aliases that redefine commands and slow
start-up; Starship does one job. Known pitfall from community discussions:
language modules call slow tools, so supershell lists modules explicitly and
keeps toolchain modules off unless devops is on.

## Fuzzy finder: fzf

Industry standard; ships Bash integration (`fzf --bash`, ≥ 0.48) for Ctrl-R,
Ctrl-T, Alt-C and `**<Tab>`. Uses `fd` for listing and `bat` for previews.

## Navigation: zoxide

Learns frequently used folders; `z name`. Initialised without `--cmd cd`, so
`cd` itself is untouched. In Ubuntu 26.04's archive (0.9.8).

## Files: eza, bat, fd, ripgrep

All maintained, all in Ubuntu's archive. Exposed under their own names (`ll`,
`la`, `lt`, `bat`, `fd`, `rg`) — never as `ls`/`cat`/`find`/`grep`.

## History: Atuin (optional, local-only)

Searchable history with directory, exit code and duration. Sync, update checks and
telemetry off; secrets filter on. Atuin's own docs recommend ble.sh for Bash
because `bash-preexec` has limitations with subshells and `ignorespace`, so in
supershell Atuin runs only together with ble.sh (`plus`). fzf's Ctrl-R covers the
default install with zero extra cost.

## Line editor: ble.sh (optional)

The only way to get fish-like syntax highlighting and autosuggestions in Bash.
Pure Bash, so it adds roughly 100 ms+ to start-up, and community reports show it
can conflict with custom key bindings. Therefore optional, loaded detached first
and attached last, with fzf integration through ble.sh's own modules.

## Editor: Neovim 0.12 (default), Helix (optional)

| | Neovim 0.12 + small profile | Helix | LazyVim-style distro | micro |
|---|---|---|---|---|
| Vim skills carry over (servers!) | yes | no — selection-first model | yes | no |
| LSP out of the box | built-in client + `vim.lsp.enable` | yes, zero config | yes | plugin |
| Plugin manager | built-in `vim.pack` | no plugin system | lazy.nvim | — |
| Maintenance burden | low (5 plugins) | lowest | high (dozens of plugins) | low |
| Adoption | high | small | high | small |

The user already uses `vi`; Helix would require unlearning Vim habits, which hurts
on servers where only `vi` exists. Neovim 0.12's built-in package manager and LSP
API removed most of the old configuration burden, so a readable profile with five
plugins (nvim-lspconfig, mason.nvim, mini.nvim, fzf-lua, gitsigns) gives LSP,
completion, fuzzy finding, a file browser, key hints and git signs. Helix stays
available as a module for people who want zero configuration.

## Git: delta (default), lazygit (optional)

delta changes only how diffs are displayed. lazygit is a full UI; it's opt-in
because learning plain Git first matters.

## Multiplexer: tmux (optional)

Available on every server, light. Optional and never auto-started — full-screen
programs and VTE's BiDi don't mix (see docs/arabic.md). Zellij was considered:
nicer UI, but heavier and rarely present on servers.

## Fonts: DejaVu Sans Mono + Symbols Nerd Font fallback

Patched Nerd Fonts replace your font. Instead supershell installs the
symbols-only Nerd Font and lets fontconfig use it only for icon glyphs (Nerd
Fonts' own docs describe fallback as an alternative to patching). DejaVu Sans
Mono contains monospaced Arabic glyphs, avoiding the "choppy Arabic" seen with
fonts that lack them.

## Terminal: Ptyxis (Ubuntu 26.04 default)

VTE-based terminals have the most complete BiDi (right-to-left) implementation
among Linux terminals. GPU terminals (Kitty, Alacritty, WezTerm, Ghostty) are fast
but their Arabic support is weaker, so supershell recommends staying on Ptyxis.

## Rejected

- **oh-my-bash / bash-it** — slow start-up, redefine commands.
- **zsh/fish as default** — differs from servers and tutorials.
- **curl-pipe installers** (`curl … | sh`) — unverifiable.
- **Patched Nerd Fonts** — replace the user's font; symbols-only fallback is enough.
