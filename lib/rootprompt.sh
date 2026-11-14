# shellcheck shell=bash
# The supershell prompt in root shells (su -, sudo -i, sudo -s).
#
# Security rule: a root shell never reads or runs a file that a normal user can
# change. `supershell root on` therefore COPIES what the prompt needs into
# root-owned places, once, with sudo:
#   /etc/supershell/root/            init.bash, starship.toml, starship-plain.toml,
#                                    starship-init.bash, bashrc.before (backup)
#   /usr/local/lib/supershell/       starship (only when yours is not root-owned)
# and adds a marked block to /root/.bashrc that sources the root-owned init.bash.
# Only the prompt: no aliases, no ble.sh, no completions — root shells stay plain.
# Prompt configs with [custom] modules (which run commands) are refused.
#
# Paths are overridable for the test suite only.
ROOT_ETC="${SUPERSHELL_ROOT_ETC:-/etc/supershell/root}"
ROOT_LIB="${SUPERSHELL_ROOT_LIB:-/usr/local/lib/supershell}"
ROOT_HOME="${SUPERSHELL_ROOT_HOME:-/root}"
ROOT_RC="$ROOT_HOME/.bashrc"
ROOT_BLOCK_BEGIN="# >>> supershell root prompt >>> (remove with: supershell root off)"
ROOT_BLOCK_END="# <<< supershell root prompt <<<"
# owner of the installed files; empty = leave as created (test suite, no real root)
ROOT_OWNER="${SUPERSHELL_ROOT_OWNER-root:root}"

root_prompt_on() { [[ -r "$ROOT_ETC/init.bash" ]]; }

# Install one file root-owned (0644, or the mode given).
_root_install() {   # <src> <dest> [mode]
  local own=()
  [[ -n "$ROOT_OWNER" ]] && own=(-o "${ROOT_OWNER%%:*}" -g "${ROOT_OWNER##*:}")
  run_root install -m "${3:-0644}" "${own[@]}" -- "$1" "$2"
}

# The rendered prompt files root should get: the user's current style (Nerd icons)
# and the plain one (SSH / Linux console).
_root_prompt_sources() {
  local style; style="$(config_get prompt_style)"
  local nerd="$SS_CONFIG_DIR/starship-$style.toml"
  # supershell-theme renders a root version with the root palette (theme_root_colors)
  [[ "$style" == supershell-theme ]] && nerd="$SS_CONFIG_DIR/starship-supershell-theme-root.toml"
  [[ "$style" == simple || ! -f "$nerd" ]] && nerd="$SS_CONFIG_DIR/starship-nerd.toml"
  printf '%s\n%s\n' "$nerd" "$SS_CONFIG_DIR/starship-plain.toml"
}

# starship's [custom.*] modules run shell commands: never copy one into root's prompt.
_root_reject_custom() {
  local f
  for f in "$@"; do
    if grep -qE '^[[:space:]]*\[custom(\.|\])|\$\{?custom' "$f"; then
      die "Your prompt uses starship [custom] modules (they run commands), which supershell never copies into a root shell: ${f/#$HOME/\~}
   Remove them from ~/.config/supershell/prompt.toml, run: supershell prompt apply, then: supershell root on"
    fi
  done
}

# A binary root may run as is: owned by root and not writable by group/others.
_root_owned_safe() {
  local p="$1" st
  st="$(stat -Lc '%u %A' -- "$p" 2>/dev/null)" || return 1
  [[ "${st%% *}" == 0 && "${st#* }" != ?????w* && "${st#* }" != ????????w* ]]
}

# A refused/failed `root on`: drop the work dir and, unless a working setup already
# exists, the root-owned binary and empty folders this attempt created.
_root_abort() {   # <workdir> <bin> <src>
  rm -rf -- "$1"
  root_prompt_on && return 0
  [[ "$2" != "$3" && "$ROOT_LIB" == */supershell ]] && run_root rm -f -- "$2"
  run_root rmdir -- "$ROOT_LIB" "$ROOT_ETC" "${ROOT_ETC%/root}" 2>/dev/null || true
}

cmd_root() {
  ensure_dirs; config_init_defaults
  case "${1:-status}" in
    on)  _root_on ;;
    off) _root_off ;;
    status)
      if root_prompt_on; then echo "root prompt: on ($ROOT_ETC)"; _root_freshness_note
      else echo "root prompt: off  (supershell root on)"; fi ;;
    *) die "Usage: supershell root [on|off|status]" ;;
  esac
}

_root_on() {
  module_is_installed core || die "Install the prompt first: supershell install core"
  local nerd plain src bin w
  { read -r nerd; read -r plain; } < <(_root_prompt_sources)
  [[ -f "$nerd" && -f "$plain" ]] || die "Prompt configs are missing — run: supershell prompt apply"
  _root_reject_custom "$nerd" "$plain"
  src="$(command -v starship)" || die "starship not found — run: supershell install core"
  src="$(readlink -f -- "$src")"
  if _root_owned_safe "$src"; then bin="$src"; else bin="$ROOT_LIB/starship"; fi

  info "Setting up the supershell prompt for root shells (su -, sudo -i, sudo -s)"
  detail "root-owned copies in $ROOT_ETC$([[ $bin != "$src" ]] && echo " and $bin")"
  detail "root's shell will not read any file you can change; prompt only (no aliases)"
  [[ "$SS_DRY_RUN" == 1 ]] && { detail "dry-run: nothing changed"; return 0; }

  w="$(mktemp -d "$SS_CACHE/root.XXXXXX")"
  # Root's own binary first. `starship init` writes into the script the `starship` it
  # finds on PATH (e.g. ~/.local/bin/starship), not the binary that is running — so
  # the script is printed by root's copy in a clean environment whose PATH starts at
  # that copy, never by editing paths afterwards.
  run_root install -d -m 0755 -- "$ROOT_ETC"
  if [[ "$bin" != "$src" ]]; then run_root install -d -m 0755 -- "$ROOT_LIB"; _root_install "$src" "$bin" 0755; fi
  env -i HOME="$HOME" LANG=C.UTF-8 PATH="${bin%/*}:/usr/sbin:/usr/bin:/sbin:/bin" \
    "$bin" init bash --print-full-init >"$w/starship-init.bash"
  [[ -s "$w/starship-init.bash" ]] || { _root_abort "$w" "$bin" "$src"; die "starship init produced nothing"; }
  # every starship the script runs must be root's copy — nothing else, nothing in $HOME
  local other
  other="$(grep -oE '[^[:space:]"($]*starship[[:space:]]+(prompt|time|init|module)' "$w/starship-init.bash" \
           | awk '{print $1}' | sort -u | grep -vxF -- "$bin" || true)"
  if [[ -n "$other" ]] || grep -qF -- "$HOME" "$w/starship-init.bash"; then
    _root_abort "$w" "$bin" "$src"
    die "refusing: root's prompt script would run a starship other than $bin (${other:-a path in $HOME})"
  fi
  cat >"$w/init.bash" <<EOF
# supershell prompt for root shells — installed by \`supershell root on\`.
# Root-owned; reads nothing a normal user can change. Remove: supershell root off
[[ \$- == *i* ]] || return 0
[[ -n "\${SUPERSHELL_DISABLE:-}" ]] && return 0
if [[ -n "\${SSH_CONNECTION:-}\${SSH_TTY:-}" || "\${TERM:-}" == linux ]]; then
  export STARSHIP_CONFIG="$ROOT_ETC/starship-plain.toml"
else
  export STARSHIP_CONFIG="$ROOT_ETC/starship.toml"
fi
[[ -r "\$STARSHIP_CONFIG" && -r "$ROOT_ETC/starship-init.bash" ]] && . "$ROOT_ETC/starship-init.bash"
EOF
  printf '%s\n%s\n%s\n' "$ROOT_BLOCK_BEGIN" "[ -r \"$ROOT_ETC/init.bash\" ] && . \"$ROOT_ETC/init.bash\"" "$ROOT_BLOCK_END" >"$w/block"

  _root_install "$nerd" "$ROOT_ETC/starship.toml"
  _root_install "$plain" "$ROOT_ETC/starship-plain.toml"
  _root_install "$w/starship-init.bash" "$ROOT_ETC/starship-init.bash"
  _root_install "$w/init.bash" "$ROOT_ETC/init.bash"

  # /root/.bashrc: back it up once, then append the block (once)
  if run_root test -e "$ROOT_RC"; then
    run_root test -e "$ROOT_ETC/bashrc.before" || run_root cp -a -- "$ROOT_RC" "$ROOT_ETC/bashrc.before"
  fi
  if ! run_root grep -qxF -- "$ROOT_BLOCK_BEGIN" "$ROOT_RC" 2>/dev/null; then
    run_root tee -a -- "$ROOT_RC" <"$w/block" >/dev/null
  fi
  rm -rf -- "$w"
  ok "root prompt: on — open a root shell (sudo -i) to see it"
  [[ "$(config_get prompt_style)" == supershell-theme ]] && detail "colours in root shells: $(config_get theme_root_colors) (supershell theme root-colors <name>)"
  detail "changing your prompt or colours later updates root's copy too (asks for sudo)"
}

_root_off() {
  if run_root grep -qxF -- "$ROOT_BLOCK_BEGIN" "$ROOT_RC" 2>/dev/null; then
    # delete exactly the lines supershell appended
    run_root sed -i '/^# >>> supershell root prompt >>>/,/^# <<< supershell root prompt <<</d' -- "$ROOT_RC"
    detail "removed the block from $ROOT_RC"
  fi
  # only paths supershell created (guarded: they must end in /supershell…)
  [[ "$ROOT_ETC" == */supershell/root ]] && run_root rm -rf -- "$ROOT_ETC"
  if [[ "$ROOT_LIB" == */supershell ]]; then
    run_root rm -f -- "$ROOT_LIB/starship"
    run_root rmdir -- "$ROOT_LIB" 2>/dev/null || true
  fi
  run_root rmdir -- "${ROOT_ETC%/root}" 2>/dev/null || true
  ok "root prompt: off — root shells are back to Ubuntu's prompt"
}

# Is root's copy the same as the user's current prompt?
_root_fresh() {
  local nerd plain
  { read -r nerd; read -r plain; } < <(_root_prompt_sources)
  cmp -s -- "$nerd" "$ROOT_ETC/starship.toml" && cmp -s -- "$plain" "$ROOT_ETC/starship-plain.toml"
}
_root_freshness_note() {
  _root_fresh && detail "up to date with your prompt" || detail "older than your current prompt — run: supershell root on"
}

root_doctor() {
  root_prompt_on || return 0
  if _root_fresh; then check_ok "root prompt: on, same as yours ($ROOT_ETC)"
  else check_warn "root prompt is older than your current prompt — run: supershell root on"; fi
  local f bad=""
  for f in "$ROOT_ETC"/*; do _root_owned_safe "$f" || bad+=" ${f##*/}"; done
  [[ -z "$bad" || -z "$ROOT_OWNER" ]] && check_ok "root prompt files are root-owned and not writable by others" \
    || check_fail "root prompt files changeable by non-root:$bad — run: supershell root on"
}
