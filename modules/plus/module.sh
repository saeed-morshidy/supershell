# shellcheck shell=bash
# plus — fish-like editing for Bash: syntax colours, grey suggestions (ble.sh)
# and searchable history with context (Atuin, local only).
MOD_DESC="Suggestions as you type + syntax colours (ble.sh), history search (Atuin, local) — adds ~100 ms start-up"
MOD_DEFAULT=yes
MOD_TOOLS="blesh atuin"
MOD_DEPS="core"

ATUIN_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/atuin/config.toml"

mod_install() {
  install_tool blesh
  install_tool atuin
  install_config "$SS_APP/config/atuin/config.toml" "$ATUIN_CFG"
  if have atuin && [[ ! -f "$SS_STATE/atuin-imported" && -s "$HOME/.bash_history" ]]; then
    if atuin import bash >/dev/null 2>&1; then
      touch "$SS_STATE/atuin-imported"; detail "imported your existing bash history into Atuin (local)"
    fi
  fi
}

mod_remove() {
  remove_tool blesh
  remove_tool atuin
  remove_config "$ATUIN_CFG"
  rmdir -- "$(dirname "$ATUIN_CFG")" 2>/dev/null || true
  detail "Atuin's history database (~/.local/share/atuin) was kept. Delete it yourself if you want."
  rm -f -- "$SS_STATE/atuin-imported"
}

mod_doctor() {
  local f; f="$(compgen -G "$SS_OPT/blesh/*/ble.sh" | tail -1 || true)"   # no match is normal (Ubuntu package)
  [[ -z "$f" && -r "${SUPERSHELL_BLESH:-/usr/share/blesh/ble.sh}" ]] && f="${SUPERSHELL_BLESH:-/usr/share/blesh/ble.sh}"
  [[ -n "$f" ]] && check_ok "ble.sh at ${f/#$HOME/\~}" || check_fail "ble.sh not found"
  have atuin && check_ok "atuin $(atuin --version 2>/dev/null | awk '{print $2}')" || check_fail "atuin not found"
  if have atuin; then
    local cfg="$ATUIN_CFG"
    grep -Eq '^\s*auto_sync\s*=\s*false' "$cfg" 2>/dev/null && check_ok "Atuin sync is off" || check_warn "Atuin auto_sync is not explicitly off in ${cfg/#$HOME/\~}"
  fi
  [[ "$(config_get plus_ble)" == off && "$(config_get plus_atuin)" == on ]] && check_warn "Atuin needs ble.sh in supershell; with plus_ble=off history is not recorded"
  return 0
}
