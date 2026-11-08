# shellcheck shell=bash
# supershell — interactive shell initialisation.
# Sourced from the one marked block in ~/.bashrc. Rules this file must keep:
#   * act only in interactive shells (scripts, scp, rsync, `bash -c` are untouched)
#   * print nothing, ever
#   * no network, no daemons, and no subprocess that isn't cached
#   * never redefine a standard command (ls, cat, grep, find, cd, vi …)

[[ $- == *i* ]] || return 0
[[ -n "${SUPERSHELL_DISABLE:-}" ]] && return 0
[[ -n "${__SS_LOADED:-}" ]] && return 0
__SS_LOADED=1

__ss_app="${BASH_SOURCE[0]%/shell/init.bash}"
__ss_state="${SUPERSHELL_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/supershell}"
__ss_cfgdir="${SUPERSHELL_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/supershell}"
__ss_cache="${SUPERSHELL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/supershell}"
__ss_opt="${SUPERSHELL_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/supershell}/opt"

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH="$HOME/.local/bin:$PATH" ;;
esac

# ---- settings (plain key=value, read without forking) ------------------------------
declare -gA __ss_cfg=([mode]=modern [icons]=auto [devops]=on [devops_aliases]=off
  [plus_ble]=on [plus_atuin]=on [set_editor]=on [nerd_font_installed]=no [prompt_style]=pastel-powerline)
if [[ -r "$__ss_cfgdir/config" ]]; then
  while IFS='=' read -r __ss_k __ss_v; do
    [[ -z "$__ss_k" || "$__ss_k" == \#* ]] && continue
    __ss_cfg[$__ss_k]="$__ss_v"
  done <"$__ss_cfgdir/config"
  unset __ss_k __ss_v
fi
[[ -n "${SUPERSHELL_MODE:-}" ]] && __ss_cfg[mode]="$SUPERSHELL_MODE"

# classic = the user's own, unmodified Bash.
[[ "${__ss_cfg[mode]}" == classic ]] && return 0

# ---- icon style: Nerd Font glyphs only where we know they can render ---------------
__ss_icons=plain
case "${__ss_cfg[icons]}" in
  nerd) __ss_icons=nerd ;;
  auto)
    if [[ "${__ss_cfg[nerd_font_installed]}" == yes && -z "${SSH_CONNECTION:-}${SSH_TTY:-}" \
          && "${TERM:-}" != linux ]]; then
      __ss_icons=nerd
    fi ;;
esac
export SUPERSHELL_ICONS="$__ss_icons"

# ---- helpers available to module shell files -------------------------------------
# Find a command on PATH without forking (sets REPLY).
__ss_which() {
  local d IFS=:
  for d in $PATH; do
    [[ -n "$d" && -x "$d/$1" && ! -d "$d/$1" ]] && { REPLY="$d/$1"; return 0; }
  done
  return 1
}

# Source the output of `<cmd> init …` from a cache, regenerated only when the
# binary changes. Saves a fork + exec per tool on every new terminal.
__ss_eval_cached() {
  local name="$1" bin file REPLY head=""
  __ss_which "$2" || return 1
  bin="$REPLY"
  file="$__ss_cache/init/$name.bash"
  # The first line records which binary wrote the cache: init scripts embed its path,
  # so a different binary (apt -> release, another PATH) must rebuild it. `-nt` alone
  # misses that: a release keeps its (older) build date. Reading one line forks nothing.
  [[ -s "$file" ]] && IFS= read -r head <"$file"
  if [[ "$head" != "# supershell-cache bin=$bin" || "$bin" -nt "$file" ]]; then
    [[ -d "$__ss_cache/init" ]] || mkdir -p "$__ss_cache/init"
    if { printf '# supershell-cache bin=%s\n' "$bin"; "${@:2}"; } >"$file.$$" 2>/dev/null \
       && [[ $(wc -l <"$file.$$") -gt 1 ]]; then
      mv -f "$file.$$" "$file"
    else
      rm -f "$file.$$"; return 1
    fi
  fi
  # shellcheck source=/dev/null
  . "$file"
}

# Define an alias unless the user already has their own (Ubuntu's stock
# definitions, passed as $3, count as "not the user's own").
__ss_alias() {
  if [[ -n "${BASH_ALIASES[$1]+set}" ]]; then
    [[ "${BASH_ALIASES[$1]}" == "${3-}" ]] || return 0
  fi
  # shellcheck disable=SC2139  # expand now, on purpose
  alias "$1=$2"
}

__ss_mods=()
[[ -r "$__ss_state/modules" ]] && mapfile -t __ss_mods <"$__ss_state/modules"
__ss_has() { local m; for m in "${__ss_mods[@]}"; do [[ "$m" == "$1" ]] && return 0; done; return 1; }

# ---- modules ------------------------------------------------------------------------
# ble.sh must be loaded first (detached) and attached last.
if __ss_has plus && [[ "${__ss_cfg[plus_ble]}" == on && -r "$__ss_app/modules/plus/pre.bash" ]]; then
  # shellcheck source=../modules/plus/pre.bash
  . "$__ss_app/modules/plus/pre.bash"
fi

for __ss_m in core git lazygit editor helix devops tmux; do
  if __ss_has "$__ss_m" && [[ -r "$__ss_app/modules/$__ss_m/shell.bash" ]]; then
    # shellcheck source=/dev/null
    . "$__ss_app/modules/$__ss_m/shell.bash"
  fi
done
unset __ss_m

if __ss_has plus && [[ -r "$__ss_app/modules/plus/shell.bash" ]]; then
  # shellcheck source=../modules/plus/shell.bash
  . "$__ss_app/modules/plus/shell.bash"
fi

return 0
