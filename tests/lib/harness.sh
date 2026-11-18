# shellcheck shell=bash
# Minimal, dependency-free test harness (bats is not required to run the suite).
# Every test runs in a throw-away HOME with stubbed apt/sudo/curl and fake tools,
# so the suite never touches the real system and needs no network.

T_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T_STUBS="$T_REPO/tests/stubs"
# Recorded before t_sandbox replaces PATH and HOME: a real Neovim (e.g. the release
# supershell installs into ~/.local/bin) and the profile's downloaded plugins.
T_REAL_NVIM="$(command -v nvim 2>/dev/null || true)"
T_REAL_NVIM_PACK="${XDG_DATA_HOME:-$HOME/.local/share}/supershell-nvim/site/pack"
T_REAL_STARSHIP="$(command -v starship 2>/dev/null || true)"
T_REAL_EZA="$(command -v eza 2>/dev/null || true)"
T_REAL_BAT="$(command -v bat 2>/dev/null || command -v batcat 2>/dev/null || true)"

t_fail() { printf '    FAIL: %s\n' "$*" >&2; exit 1; }
t_skip() { printf '    SKIP: %s\n' "$*" >&2; exit 77; }

assert_eq()        { [[ "$1" == "$2" ]] || t_fail "${3:-values differ}: expected [$2] got [$1]"; }
assert_ne()        { [[ "$1" != "$2" ]] || t_fail "${3:-values should differ}: [$1]"; }
assert_contains()  { [[ "$1" == *"$2"* ]] || t_fail "${3:-missing text}: expected to find [$2] in [${1:0:400}]"; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || t_fail "${3:-unexpected text}: found [$2] in [${1:0:400}]"; }
assert_file()      { [[ -e "$1" || -L "$1" ]] || t_fail "expected file $1"; }
assert_no_file()   { [[ ! -e "$1" && ! -L "$1" ]] || t_fail "expected no file $1"; }
assert_ok()        { "$@" || t_fail "command failed: $*"; }
assert_fails()     { if "$@"; then t_fail "command should have failed: $*"; fi; }
assert_same_file() { cmp -s -- "$1" "$2" || t_fail "files differ: $1 vs $2 ($(diff "$1" "$2" | head -5))"; }

# Fresh sandbox: $T_TMP/home is HOME; fake /usr/bin for stubbed packages.
t_sandbox() {
  T_TMP="$(mktemp -d "${TMPDIR:-/tmp}/ss-test.XXXXXX")"
  export HOME="$T_TMP/home"
  mkdir -p "$HOME" "$T_TMP/usr/bin" "$T_TMP/apt" "$T_TMP/dl"
  unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME STARSHIP_CONFIG EDITOR VISUAL \
        NVIM_APPNAME SSH_CONNECTION SSH_TTY SUPERSHELL_DISABLE SUPERSHELL_MODE BLE_VERSION \
        FZF_DEFAULT_OPTS FZF_DEFAULT_COMMAND BAT_THEME GIT_CONFIG_GLOBAL __SS_LOADED
  export LANG=C.UTF-8 LC_ALL=C.UTF-8 TERM=xterm-256color NO_COLOR=1
  export T_REPO T_TMP T_FAKE_BIN="$T_TMP/usr/bin" T_APT="$T_TMP/apt" T_DL="$T_TMP/dl"
  export PATH="$T_STUBS/bin:$HOME/.local/bin:$T_FAKE_BIN:/usr/local/bin:/usr/bin:/bin"
  export SUPERSHELL_OS_RELEASE="$T_TMP/os-release" SUPERSHELL_ARCH=x86_64
  # the fake `ble.sh` package installs here — never the host's /usr/share/blesh
  export SUPERSHELL_BLESH="$T_TMP/usr/share/blesh/ble.sh"
  # font fitting depends on the host's fonts and screen: a stub, unless a test says so
  export SUPERSHELL_FONTFIT="$T_STUBS/fontfit.py" SUPERSHELL_DPI=96
  # root prompt: a fake /root, /etc and /usr/local/lib (the sudo stub runs unprivileged)
  export SUPERSHELL_ROOT_HOME="$T_TMP/root" SUPERSHELL_ROOT_ETC="$T_TMP/etc/supershell/root" \
         SUPERSHELL_ROOT_LIB="$T_TMP/usr/local/lib/supershell" SUPERSHELL_ROOT_OWNER=""
  mkdir -p "$T_TMP/root"
  printf '%s\n' '# ~/.bashrc: executed by bash(1) for non-login shells.' '[ -z "$PS1" ] && return' 'PS1='"'"'\u@\h:\w\$ '"'"'' >"$T_TMP/root/.bashrc"
  t_os ubuntu 26.04 resolute
  # Default apt archive: every tool available and new enough.
  cat >"$T_APT/available" <<'AVAIL'
starship 1.27.0-1 starship
fzf 0.62.0-1 fzf
zoxide 0.9.8-1 zoxide
eza 0.21.0-1 eza
bat 0.25.0-1 batcat
fd-find 10.2.0-1 fdfind
ripgrep 14.1.1-1 rg
git-delta 0.18.2-1 delta
neovim 0.12.6-1 nvim
atuin 18.15.2-1 atuin
ble.sh 0.4.0~git20250806.8060b7a-1 -
tmux 3.5a-1 tmux
lazygit 0.50.0-1 lazygit
fonts-dejavu-core 2.37-8 -
fonts-cascadia-code 2407.24-3 -
fonts-jetbrains-mono 2.304+ds-6 -
fonts-firacode 6.2-3 -
fonts-ibm-plex 6.1.1-1 -
fonts-ubuntu 0.869-0ubuntu2 -
wl-clipboard 2.2.1-2 wl-copy
fontconfig 2.15-1 -
git 2.51-1 -
AVAIL
  : >"$T_APT/installed"
  git config --global user.name test >/dev/null 2>&1 || true
  t_fixture_nerd
}

# Release archive for the icon font, with an upstream checksum file (as published).
t_fixture_nerd() {
  local d="$T_TMP/fx-nerd"; mkdir -p "$d/pkg"
  echo "fake font" >"$d/pkg/SymbolsNerdFontMono-Regular.ttf"
  echo "fake font" >"$d/pkg/SymbolsNerdFont-Regular.ttf"
  tar -cJf "$T_DL/NerdFontsSymbolsOnly.tar.xz" -C "$d/pkg" .
  (cd "$T_DL" && sha256sum NerdFontsSymbolsOnly.tar.xz >SHA-256.txt)
  # The real manifest pins the real font; use a test copy pinned to this fake one.
  local h; h="$(awk '{print $1}' "$T_DL/SHA-256.txt")"
  awk -v h="$h" '/^\[/ {n = ($0 == "[nerd-symbols]")} n && /^sha256\./ {sub(/=.*/, "= " h)} {print}' \
    "$T_REPO/manifest/tools.ini" >"$T_TMP/tools.ini"
  export SUPERSHELL_MANIFEST="$T_TMP/tools.ini"
}

# Load the CLI libraries into the current shell for unit tests.
t_load_lib() {
  SS_ROOT="$T_REPO"
  # shellcheck source=/dev/null
  for f in common os state backup bashrc tools modules rootprompt; do . "$T_REPO/lib/$f.sh"; done
  ensure_dirs
}

t_os() { printf 'ID=%s\nVERSION_ID="%s"\nVERSION_CODENAME=%s\n' "$1" "$2" "$3" >"$SUPERSHELL_OS_RELEASE"; }

t_cleanup() { [[ -n "${T_TMP:-}" && "$T_TMP" == */ss-test.* ]] && rm -rf -- "$T_TMP"; }

# The CI sandbox may run as root; the root guard itself is tested separately.
ss() { if [[ $EUID -eq 0 ]]; then "$T_REPO/supershell" --allow-root "$@" </dev/null; else "$T_REPO/supershell" "$@" </dev/null; fi; }

# Run commands in an interactive bash that reads ~/.bashrc. Sets T_OUT / T_ERR.
t_ibash() {
  local errf="$T_TMP/ibash.err"
  T_OUT="$(cd "$HOME" && bash -i -c "$1" </dev/null 2>"$errf")" || true
  T_ERR="$(grep -v -e 'no job control' -e 'cannot set terminal process group' -e 'Inappropriate ioctl' "$errf" || true)"
}

# Seed a typical Ubuntu ~/.bashrc plus some user customisation.
t_ubuntu_bashrc() {
  cat >"$HOME/.bashrc" <<'RC'
# ~/.bashrc: executed by bash(1) for non-login shells.
case $- in
    *i*) ;;
      *) return;;
esac
HISTCONTROL=ignoreboth
shopt -s histappend
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias gs='git status'
mytool() { echo "user function works"; }
export MY_VAR=hello
RC
}
