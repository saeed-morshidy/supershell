# shellcheck shell=bash
# Module discovery and the install/remove orchestration.
#
# A module is modules/<name>/module.sh defining:
#   MOD_DESC, MOD_DEFAULT (yes|no), MOD_DEPS ("a b")
#   mod_install, mod_remove, mod_doctor   (required)
#   mod_apply                             (optional: re-render after config changes)
# and optionally modules/<name>/shell.bash, sourced by interactive shells.

SS_MODULE_ORDER=(core git editor fonts devops lazygit helix plus tmux)

module_dir() { printf '%s/modules/%s\n' "$SS_ROOT" "$1"; }
module_exists() { [[ -f "$(module_dir "$1")/module.sh" ]]; }

module_load() {
  unset -f mod_install mod_remove mod_doctor mod_apply 2>/dev/null || true
  MOD_DESC="" MOD_DEFAULT=no MOD_DEPS="" MOD_TOOLS="" MOD_PKGS=""
  MOD_NAME="$1"
  MOD_DIR="$(module_dir "$1")"
  module_exists "$1" || die "Unknown module '$1'. Run: supershell list"
  # shellcheck source=/dev/null
  . "$MOD_DIR/module.sh"
}

modules_all() { printf '%s\n' "${SS_MODULE_ORDER[@]}"; }

modules_default() {
  local m
  for m in "${SS_MODULE_ORDER[@]}"; do
    if ( module_load "$m"; [[ "$MOD_DEFAULT" == yes ]] ); then echo "$m"; fi
  done
  return 0
}

# Expand dependencies and sort into canonical order.
modules_resolve() {
  local -A want=()
  local m d queue=("$@")
  while ((${#queue[@]})); do
    m="${queue[0]}"; queue=("${queue[@]:1}")
    [[ -n "${want[$m]:-}" ]] && continue
    module_exists "$m" || die "Unknown module '$m'. Run: supershell list"
    want[$m]=1
    for d in $( module_load "$m"; echo "$MOD_DEPS" ); do queue+=("$d"); done
  done
  for m in "${SS_MODULE_ORDER[@]}"; do if [[ -n "${want[$m]:-}" ]]; then echo "$m"; fi; done
  return 0
}

# ---- managed config files ---------------------------------------------------------
SS_CONFIGS_FILE="$SS_STATE/configs"

_config_recorded_hash() { [[ -f "$SS_CONFIGS_FILE" ]] || return 0; awk -F'\t' -v d="$1" '$1==d{print $2}' "$SS_CONFIGS_FILE"; }
_config_record() {
  mkdir -p "$SS_STATE"
  { [[ -f "$SS_CONFIGS_FILE" ]] && awk -F'\t' -v d="$1" '$1!=d' "$SS_CONFIGS_FILE"
    if [[ -n "${2:-}" ]]; then printf '%s\t%s\n' "$1" "$2"; fi; } | atomic_write "$SS_CONFIGS_FILE"
}

# install_config <src> <dest>
# New file -> written. Our previous version -> updated (with backup).
# A file the user wrote or edited -> left alone; ours is placed next to it.
install_config() {
  local src="$1" dest="$2" cur rec new
  new="$(sha256_of "$src")"
  mkdir -p "$(dirname "$dest")"
  if [[ ! -e "$dest" && ! -L "$dest" ]]; then
    journal_add absent "$dest"
    run cp -- "$src" "$dest"
    _config_record "$dest" "$new"
    detail "wrote ${dest/#$HOME/\~}"
    return 0
  fi
  cur="$(sha256_of "$dest" 2>/dev/null || true)"
  [[ "$cur" == "$new" ]] && { _config_record "$dest" "$new"; return 0; }
  rec="$(_config_recorded_hash "$dest")"
  if [[ -n "$rec" && "$cur" == "$rec" ]]; then
    journal_track_file "$dest"
    run cp -- "$src" "$dest"
    _config_record "$dest" "$new"
    detail "updated ${dest/#$HOME/\~}"
  else
    run cp -- "$src" "$dest.supershell"
    journal_add absent "$dest.supershell"
    warn "Kept your existing ${dest/#$HOME/\~}; the supershell version is at ${dest/#$HOME/\~}.supershell"
  fi
}

# Remove a config only if it is still exactly what we wrote.
remove_config() {
  local dest="$1" rec cur
  rm -f -- "$dest.supershell"
  [[ -e "$dest" ]] || { _config_record "$dest" ""; return 0; }
  rec="$(_config_recorded_hash "$dest")"
  cur="$(sha256_of "$dest")"
  if [[ -n "$rec" && "$cur" == "$rec" ]]; then
    run rm -f -- "$dest"; detail "removed ${dest/#$HOME/\~}"
  elif [[ -n "$rec" ]]; then
    backup_file "$dest" >/dev/null
    warn "You edited ${dest/#$HOME/\~}; it was kept (a backup copy was also saved)"
  fi
  _config_record "$dest" ""
}

# ---- doctor helpers -------------------------------------------------------------
DOC_OK=0 DOC_WARN=0 DOC_FAIL=0
check_ok()   { printf '  %s✓%s %s\n' "$_c_grn" "$_c_rst" "$*"; DOC_OK=$((DOC_OK+1)); }
check_warn() { printf '  %s!%s %s\n' "$_c_ylw" "$_c_rst" "$*"; DOC_WARN=$((DOC_WARN+1)); }
check_fail() { printf '  %s✗%s %s\n' "$_c_red" "$_c_rst" "$*"; DOC_FAIL=$((DOC_FAIL+1)); }
check_cmd()  { if have "$1"; then check_ok "$1 ${2:-}"; else check_fail "$1 not found on PATH"; fi; }
