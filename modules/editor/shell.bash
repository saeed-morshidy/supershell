# shellcheck shell=bash
# editor — make the supershell Neovim profile the default, unless you have your own.
snvim() { NVIM_APPNAME=supershell-nvim nvim "$@"; }
if [[ ! -d "${XDG_CONFIG_HOME:-$HOME/.config}/nvim" && -z "${NVIM_APPNAME:-}" ]]; then
  export NVIM_APPNAME=supershell-nvim
fi
if [[ "${__ss_cfg[set_editor]}" == on && -z "${EDITOR:-}${VISUAL:-}" ]] && __ss_which nvim; then
  export EDITOR=nvim VISUAL=nvim
fi
