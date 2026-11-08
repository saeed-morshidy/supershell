# shellcheck shell=bash
# tmux — optional terminal multiplexer. Never started automatically.
MOD_DESC="tmux with sensible defaults — optional, never auto-started"
MOD_DEFAULT=no
MOD_TOOLS="tmux"
MOD_DEPS=""

TMUX_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"

mod_install() {
  install_tool tmux
  if [[ -e "$HOME/.tmux.conf" ]]; then
    info "Keeping your ~/.tmux.conf (supershell's version not installed)"
  else
    install_config "$SS_APP/config/tmux/tmux.conf" "$TMUX_CFG"
  fi
}
mod_remove() { remove_config "$TMUX_CFG"; rmdir -- "$(dirname "$TMUX_CFG")" 2>/dev/null || true; }
mod_doctor() {
  have tmux && check_ok "tmux $(tmux -V | awk '{print $2}')" || check_fail "tmux not found"
  check_ok "note: tmux draws the screen itself, so Arabic RTL display inside tmux is not reliable (docs/arabic.md)"
  return 0
}
