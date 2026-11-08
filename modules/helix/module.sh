# shellcheck shell=bash
# helix — optional second editor profile: zero-config modal editor.
MOD_DESC="Helix editor (hx) — optional, works with no configuration"
MOD_DEFAULT=no
MOD_TOOLS="helix"
MOD_DEPS=""

HX_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/helix"

mod_install() {
  install_tool helix
  install_config "$SS_APP/config/helix/config.toml" "$HX_CFG/config.toml"
  install_config "$SS_APP/config/helix/languages.toml" "$HX_CFG/languages.toml"
}
mod_remove() {
  remove_config "$HX_CFG/config.toml"; remove_config "$HX_CFG/languages.toml"
  rmdir -- "$HX_CFG" 2>/dev/null || true
  remove_tool helix
}
mod_doctor() {
  have hx && check_ok "helix $(hx --version 2>/dev/null | awk '{print $2}')" || check_fail "hx not found"
  have hx && { hx --health >/dev/null 2>&1 && check_ok "hx --health runs (see it for language servers)" || check_warn "hx --health failed"; }
  return 0
}
