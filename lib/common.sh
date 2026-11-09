# shellcheck shell=bash
# supershell — shared helpers: paths, logging, prompts, errors.
# Sourced by the CLI only (never by interactive shells).

# ---- paths (XDG-aware, overridable for tests) -------------------------------
: "${HOME:?HOME must be set}"
SS_DATA="${SUPERSHELL_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/supershell}"
SS_APP="$SS_DATA/app"            # installed copy of this repository
SS_OPT="$SS_DATA/opt"            # release binaries we manage
SS_BIN="${SUPERSHELL_BIN:-$HOME/.local/bin}"
SS_STATE="${SUPERSHELL_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/supershell}"
SS_CONFIG_DIR="${SUPERSHELL_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/supershell}"
SS_CACHE="${SUPERSHELL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/supershell}"
SS_LOG="$SS_STATE/install.log"

# Tools supershell installs from releases are linked into $SS_BIN. On a fresh system
# (or a server, `su -c`, cron…) that folder is often not on PATH yet, and the CLI must
# still find what it just installed (e.g. starship to render the prompt).
SS_USER_PATH="$PATH"   # as the user has it (doctor reports on this one)
case ":$PATH:" in *":$SS_BIN:"*) ;; *) PATH="$SS_BIN:$PATH" ;; esac

SS_ASSUME_YES="${SS_ASSUME_YES:-0}"
SS_DRY_RUN="${SS_DRY_RUN:-0}"

# ---- colors (only on a TTY, honour NO_COLOR) --------------------------------
if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
  _c_red=$'\e[31m' _c_grn=$'\e[32m' _c_ylw=$'\e[33m' _c_blu=$'\e[34m'
  _c_dim=$'\e[2m' _c_bld=$'\e[1m' _c_rst=$'\e[0m'
else
  _c_red='' _c_grn='' _c_ylw='' _c_blu='' _c_dim='' _c_bld='' _c_rst=''
fi

_ss_logfile() {
  [[ -d "$SS_STATE" ]] || return 0
  printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$SS_LOG" 2>/dev/null || true
}

info()  { printf '%s==>%s %s\n' "$_c_blu" "$_c_rst" "$*" >&2; _ss_logfile "INFO $*"; }
ok()    { printf '%s ✓ %s %s\n' "$_c_grn" "$_c_rst" "$*" >&2; _ss_logfile "OK   $*"; }
warn()  { printf '%s ! %s %s\n' "$_c_ylw" "$_c_rst" "$*" >&2; _ss_logfile "WARN $*"; }
err()   { printf '%s ✗ %s %s\n' "$_c_red" "$_c_rst" "$*" >&2; _ss_logfile "ERR  $*"; }
detail(){ printf '   %s%s%s\n' "$_c_dim" "$*" "$_c_rst" >&2; }
die()   { err "$*"; exit 1; }

# Ask a yes/no question. Default is "no" unless $2 == y.
# Non-interactive runs (no TTY) take the default; --yes forces yes.
confirm() {
  local q="$1" def="${2:-n}" ans hint="[y/N]"
  [[ "$def" == y ]] && hint="[Y/n]"
  if [[ "$SS_ASSUME_YES" == 1 ]]; then return 0; fi
  if [[ ! -t 0 ]]; then [[ "$def" == y ]]; return; fi
  read -r -p "  ? $q $hint " ans || ans=""
  ans="${ans:-$def}"
  [[ "$ans" == [yY]* ]]
}

have() { command -v "$1" >/dev/null 2>&1; }

# Run a command, or only print it in --dry-run mode.
run() {
  if [[ "$SS_DRY_RUN" == 1 ]]; then detail "dry-run: $*"; return 0; fi
  _ss_logfile "RUN  $*"
  "$@"
}

# Run with root privileges. Never caches or stores the password.
run_root() {
  if [[ $EUID -eq 0 ]]; then run "$@"; return; fi
  have sudo || die "sudo is required to install system packages (missing: sudo)"
  run sudo "$@"
}

ensure_dirs() {
  mkdir -p "$SS_DATA" "$SS_OPT" "$SS_BIN" "$SS_STATE/backups" "$SS_CONFIG_DIR" "$SS_CACHE"
}

# Path is inside a directory supershell owns (guard for any rm -rf).
ss_owned_path() {
  local p="$1"
  case "$p" in
    "$SS_DATA"|"$SS_CACHE"|"$SS_CONFIG_DIR"|"$SS_STATE") return 0 ;;
    "$SS_DATA"/*|"$SS_CACHE"/*|"$SS_CONFIG_DIR"/*|"$SS_STATE"/*) return 0 ;;
  esac
  return 1
}

# Remove a path only if supershell owns it. Refuses everything else.
safe_rm() {
  local p
  for p in "$@"; do
    [[ -n "$p" && "$p" != / ]] || die "refusing to remove '$p'"
    if ss_owned_path "$p"; then
      run rm -rf -- "$p"
    else
      die "refusing to remove '$p': not owned by supershell"
    fi
  done
}

# Write a file atomically (tmp + mv), so an interrupted run never
# leaves a half-written config behind.
atomic_write() {
  local dest="$1" tmp
  tmp="$(mktemp "${dest}.ss-tmp.XXXXXX")"
  cat >"$tmp"
  mv -f -- "$tmp" "$dest"
}
