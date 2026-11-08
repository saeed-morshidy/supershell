# Editor: Neovim profile

Neovim 0.12 with a small profile in `~/.config/supershell-nvim`. Leader key: **Space**.
`nvim` uses it unless you have your own `~/.config/nvim` (then use `snvim`).

## First steps (coming from vi)

Everything you know from `vi` works: `i`, `Esc`, `:w`, `:q`, `dd`, `yy`, `p`, `/search`.
What's new:

| Keys | Action |
|---|---|
| `Space` and wait | a popup lists what you can press next |
| `Space f` | find a file by name |
| `Space /` | search text in the whole project |
| `Space b` / `Space h` | open buffers / recent files |
| `Space e` | file browser (mini.files; `=` to apply changes) |
| `Space w` | save |
| `gd` / `gr` / `K` | go to definition / references / documentation |
| `Space ca` / `Space cr` / `Space cf` | code action / rename / format |
| `]d` `[d` / `Space d` / `Space q` | next/prev problem / show it / list all |
| `]h` `[h` / `Space gp` / `Space gb` / `Space gr` | next/prev git change / preview / blame / undo change |
| `Tab` / `Shift-Tab` | move in the completion menu; `Ctrl-y` accepts |

## Language servers

Servers are started only if installed, so nothing errors out. Install them inside
Neovim (needs network; some need Node.js):

```
:SupershellLspInstall      " bash, python, go, yaml(+k8s), json, docker, terraform, markdown, lua
:Mason                     " pick individually
```

| Language | Server | Notes |
|---|---|---|
| Bash | bash-language-server | uses `shellcheck` and `shfmt` if installed |
| Python | pyright | venv-aware |
| Go | gopls | needs Go |
| YAML / Kubernetes | yaml-language-server | k8s schema for `k8s/`, `manifests/`, `*.k8s.yaml` |
| JSON | vscode-json-language-server | SchemaStore |
| Dockerfile | dockerfile-language-server | |
| Terraform | terraform-ls | |
| Markdown | marksman | |

## Plugins

Managed by Neovim's built-in `vim.pack`; versions are recorded in
`~/.config/supershell-nvim/nvim-pack-lock.json`. Update with
`:lua vim.pack.update()` (review, then `:w` to apply).

## Arabic

See [arabic.md](arabic.md#neovim). `:ArabicView` toggles a right-to-left window
(experimental).

## Helix (optional)

`supershell install helix`, then `hx`. Run `hx --tutor` once; `hx --health` shows
which language servers it found.
