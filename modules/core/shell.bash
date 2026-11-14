# shellcheck shell=bash
# core — interactive setup. Sourced by shell/init.bash (helpers __ss_* available).

# ---- prompt ------------------------------------------------------------------------
if [[ -z "${STARSHIP_CONFIG:-}" ]]; then
  # A segmented style (e.g. gruvbox-rainbow) needs Nerd Font glyphs, so it falls back
  # to the simple prompt wherever icons are plain (SSH, Linux console, no icon font).
  if [[ "${__ss_cfg[prompt_style]}" != simple && "$__ss_icons" == nerd \
        && -f "$__ss_cfgdir/starship-${__ss_cfg[prompt_style]}.toml" ]]; then
    export STARSHIP_CONFIG="$__ss_cfgdir/starship-${__ss_cfg[prompt_style]}.toml"
  else
    export STARSHIP_CONFIG="$__ss_cfgdir/starship-$__ss_icons.toml"
  fi
fi
__ss_eval_cached starship starship init bash --print-full-init

# ---- smart cd: `z name` / `zi` (cd itself is untouched) ----------------------------
__ss_eval_cached zoxide zoxide init bash

# ---- fzf: Ctrl-R history, Ctrl-T files, Alt-C folders, **<Tab> --------------------
if __ss_which fd; then
  export FZF_DEFAULT_COMMAND="${FZF_DEFAULT_COMMAND:-fd --type f --hidden --follow --exclude .git}"
  export FZF_CTRL_T_COMMAND="${FZF_CTRL_T_COMMAND:-$FZF_DEFAULT_COMMAND}"
  export FZF_ALT_C_COMMAND="${FZF_ALT_C_COMMAND:-fd --type d --hidden --follow --exclude .git}"
  _fzf_compgen_path() { fd --hidden --follow --exclude .git . "$1"; }
  _fzf_compgen_dir()  { fd --type d --hidden --follow --exclude .git . "$1"; }
fi
# Tool colours from the theme palette (written by `supershell theme colors`); without
# it, ANSI colour numbers that follow the terminal's own palette. Yours always win.
__ss_look_palette="" __ss_look_fzf="" __ss_look_bat=""
# shellcheck source=/dev/null
[[ -r "$__ss_cfgdir/look.bash" ]] && . "$__ss_cfgdir/look.bash"
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:---height=45% --layout=reverse --border=rounded --info=inline-right \
${__ss_look_fzf:---color=fg:-1,bg:-1,hl:4,fg+:-1,bg+:-1,hl+:4,info:8,prompt:5,pointer:5,marker:2,spinner:5,header:8,border:8}}"
if __ss_which bat; then
  export FZF_CTRL_T_OPTS="${FZF_CTRL_T_OPTS:---preview 'bat --color=always --style=numbers --line-range=:200 {} 2>/dev/null'}"
fi
if [[ -n "${BLE_VERSION:-}" ]]; then
  ble-import -d integration/fzf-completion
  ble-import -d integration/fzf-key-bindings
else
  __ss_eval_cached fzf fzf --bash
fi

# ---- file tools: new names only, standard commands stay standard --------------------
export BAT_THEME="${BAT_THEME:-${__ss_look_bat:-ansi}}"   # delta follows BAT_THEME too
if __ss_which eza; then
  __ss_eza_icons="" __ss_eza_env=""
  [[ "$__ss_icons" == nerd ]] && __ss_eza_icons=" --icons=auto"
  # supershell's eza theme — unless you have your own theme or EZA_CONFIG_DIR
  if [[ -n "$__ss_look_palette" && -z "${EZA_CONFIG_DIR:-}" && -r "$__ss_cfgdir/eza/theme.yml" \
        && ! -e "${XDG_CONFIG_HOME:-$HOME/.config}/eza/theme.yml" && ! -e "${XDG_CONFIG_HOME:-$HOME/.config}/eza/theme.yaml" ]]; then
    export EZA_CONFIG_DIR="$__ss_cfgdir/eza"
    # Ubuntu's ~/.bashrc sets LS_COLORS from dircolors' defaults, which would override
    # the theme for ll/la/lt; with your own ~/.dircolors or EZA_COLORS, yours win.
    [[ ! -e "$HOME/.dircolors" && -z "${EZA_COLORS:-}" ]] && __ss_eza_env="LS_COLORS= "
  fi
  __ss_alias ll "${__ss_eza_env}eza -l --git --group-directories-first --time-style=relative${__ss_eza_icons}" "ls -alF"
  __ss_alias la "${__ss_eza_env}eza -la --git --group-directories-first --time-style=relative${__ss_eza_icons}" "ls -A"
  __ss_alias lt "${__ss_eza_env}eza --tree --level=2 --group-directories-first${__ss_eza_icons}"
  unset __ss_eza_icons __ss_eza_env
fi
unset __ss_look_palette __ss_look_fzf __ss_look_bat
