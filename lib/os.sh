# shellcheck shell=bash
# OS / architecture detection and support policy.

SS_OS_RELEASE="${SUPERSHELL_OS_RELEASE:-/etc/os-release}"
SS_SUPPORTED_PRIMARY="26.04"
SS_SUPPORTED_BEST_EFFORT="24.04 25.10"

os_detect() {
  OS_ID="" OS_VERSION="" OS_CODENAME=""
  if [[ -r "$SS_OS_RELEASE" ]]; then
    # Parse, don't source: os-release is data, not code.
    local k v
    while IFS='=' read -r k v; do
      v="${v%\"}"; v="${v#\"}"
      case "$k" in
        ID) OS_ID="$v" ;;
        VERSION_ID) OS_VERSION="$v" ;;
        VERSION_CODENAME) OS_CODENAME="$v" ;;
      esac
    done <"$SS_OS_RELEASE"
  fi
  local arch="${SUPERSHELL_ARCH:-$(uname -m)}"
  case "$arch" in
    x86_64|amd64) OS_ARCH=x86_64 ;;
    aarch64|arm64) OS_ARCH=aarch64 ;;
    *) OS_ARCH="$arch" ;;
  esac
}

# 0 = primary, 1 = best effort (warn), 2 = unsupported.
os_support_level() {
  os_detect
  [[ "$OS_ID" == ubuntu ]] || return 2
  [[ "$OS_ARCH" == x86_64 || "$OS_ARCH" == aarch64 ]] || return 2
  [[ "$OS_VERSION" == "$SS_SUPPORTED_PRIMARY" ]] && return 0
  local v
  for v in $SS_SUPPORTED_BEST_EFFORT; do [[ "$OS_VERSION" == "$v" ]] && return 1; done
  return 2
}

os_require_supported() {
  local force="${1:-0}" lvl=0
  os_support_level || lvl=$?
  case $lvl in
    0) return 0 ;;
    1) warn "Ubuntu $OS_VERSION is supported on a best-effort basis (primary target: $SS_SUPPORTED_PRIMARY)." ;;
    2)
      if [[ "$force" == 1 ]]; then
        warn "Unsupported system (${OS_ID:-unknown} ${OS_VERSION:-?} / $OS_ARCH) — continuing because of --force."
      else
        die "Unsupported system: ${OS_ID:-unknown} ${OS_VERSION:-?} ($OS_ARCH). supershell targets Ubuntu $SS_SUPPORTED_PRIMARY (x86_64/aarch64). Use --force to try anyway."
      fi ;;
  esac
}

bash_version_ok() { (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1) )); }
