# shellcheck shell=bash
# plus (part 1) — load ble.sh detached, before anything else binds keys.
__ss_ble=""
for __ss_f in "$__ss_opt"/blesh/*/ble.sh; do [[ -r "$__ss_f" ]] && __ss_ble="$__ss_f"; done
# Ubuntu's ble.sh package (the normal case); SUPERSHELL_BLESH overrides it (tests)
[[ -z "$__ss_ble" && -r "${SUPERSHELL_BLESH:-/usr/share/blesh/ble.sh}" ]] && __ss_ble="${SUPERSHELL_BLESH:-/usr/share/blesh/ble.sh}"
if [[ -n "$__ss_ble" ]]; then
  # shellcheck source=/dev/null
  . "$__ss_ble" --attach=none --rcfile "$__ss_app/config/ble/blerc"
fi
unset __ss_ble __ss_f
