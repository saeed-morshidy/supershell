# shellcheck shell=bash
# plus (part 2) — Atuin history (only with ble.sh, which gives it reliable hooks),
# then attach ble.sh as the very last step.
if [[ -n "${BLE_VERSION:-}" && "${__ss_cfg[plus_atuin]}" == on ]] && __ss_which atuin; then
  # Up-arrow keeps its normal Bash behaviour; Ctrl-R opens Atuin.
  __ss_eval_cached atuin-noup atuin init bash --disable-up-arrow
fi
if [[ -n "${BLE_VERSION:-}" ]]; then
  ble-attach
fi
