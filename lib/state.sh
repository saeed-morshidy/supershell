# shellcheck shell=bash
# User config (~/.config/supershell/config) and install state.

SS_CONFIG_FILE="$SS_CONFIG_DIR/config"

# key|allowed values|default
SS_CONFIG_SCHEMA=(
  "mode|modern classic|modern"
  "icons|auto nerd plain|auto"
  "devops|on off|on"
  "devops_aliases|on off|off"
  "plus_ble|on off|on"
  "plus_atuin|on off|on"
  "set_editor|on off|on"
  "prompt_style|supershell-theme pastel-powerline tokyo-night gruvbox-rainbow catppuccin-mocha catppuccin-macchiato catppuccin-frappe catppuccin-latte simple|supershell-theme"
  "theme_colors|supershell supershell-root pastel tokyo-night catppuccin gruvbox nord dracula rose-pine kanagawa|supershell"
  "theme_tools|on off|on"
  "theme_ends|rounded square|rounded"
  "theme_root_colors|supershell supershell-root pastel tokyo-night catppuccin gruvbox nord dracula rose-pine kanagawa same|supershell-root"
  "prompt_custom|on off|on"
  "prompt_cap|on off|off"
  "font|cascadia-code dejavu-sans-mono jetbrains-mono fira-code ibm-plex-mono ubuntu-sans-mono|cascadia-code"
  "font_fit|on off|on"
  "font_size|8 9 10 11 12 13 14 16|14"
  "nerd_font_installed|yes no|no"
)

_cfg_schema_line() {
  local key="$1" line
  for line in "${SS_CONFIG_SCHEMA[@]}"; do
    [[ "${line%%|*}" == "$key" ]] && { printf '%s\n' "$line"; return 0; }
  done
  return 1
}

config_default() { local l; l="$(_cfg_schema_line "$1")" || return 1; printf '%s\n' "${l##*|}"; }

config_get() {
  local key="$1" k v
  if [[ -f "$SS_CONFIG_FILE" ]]; then
    while IFS='=' read -r k v; do
      [[ "$k" == "$key" ]] && { printf '%s\n' "$v"; return 0; }
    done <"$SS_CONFIG_FILE"
  fi
  config_default "$key"
}

config_set() {
  local key="$1" val="$2" line allowed a found=0
  line="$(_cfg_schema_line "$key")" || die "Unknown setting '$key'. Run: supershell config list"
  allowed="${line#*|}"; allowed="${allowed%|*}"
  for a in $allowed; do [[ "$a" == "$val" ]] && found=1; done
  [[ $found == 1 ]] || die "Invalid value '$val' for '$key' (allowed: $allowed)"
  mkdir -p "$SS_CONFIG_DIR"
  {
    local k v seen=0
    if [[ -f "$SS_CONFIG_FILE" ]]; then
      while IFS='=' read -r k v; do
        [[ -z "$k" ]] && continue
        if [[ "$k" == "$key" ]]; then printf '%s=%s\n' "$key" "$val"; seen=1
        else printf '%s=%s\n' "$k" "$v"; fi
      done <"$SS_CONFIG_FILE"
    fi
    [[ $seen == 1 ]] || printf '%s=%s\n' "$key" "$val"
  } | atomic_write "$SS_CONFIG_FILE"
}

config_init_defaults() {
  mkdir -p "$SS_CONFIG_DIR"
  [[ -f "$SS_CONFIG_FILE" ]] && return 0
  {
    echo "# supershell settings — edit with: supershell config set <key> <value>"
    local line
    for line in "${SS_CONFIG_SCHEMA[@]}"; do printf '%s=%s\n' "${line%%|*}" "${line##*|}"; done
  } | atomic_write "$SS_CONFIG_FILE"
}

# ---- installed modules -------------------------------------------------------
SS_MODULES_FILE="$SS_STATE/modules"

modules_installed() { [[ -f "$SS_MODULES_FILE" ]] && grep -v '^\s*$' "$SS_MODULES_FILE" || true; }
module_is_installed() { grep -qx -- "$1" <<<"$(modules_installed)"; }

module_mark_installed() {
  mkdir -p "$SS_STATE"
  module_is_installed "$1" && return 0
  { modules_installed; echo "$1"; } | atomic_write "$SS_MODULES_FILE"
}

module_mark_removed() {
  [[ -f "$SS_MODULES_FILE" ]] || return 0
  modules_installed | grep -vx -- "$1" | atomic_write "$SS_MODULES_FILE" || true
}

# ---- tools registry: name<TAB>source<TAB>version<TAB>location ---------------
SS_TOOLS_FILE="$SS_STATE/tools"

tool_record() {
  local name="$1" src="$2" ver="$3" loc="$4"
  mkdir -p "$SS_STATE"
  { [[ -f "$SS_TOOLS_FILE" ]] && awk -F'\t' -v n="$name" '$1!=n' "$SS_TOOLS_FILE"
    printf '%s\t%s\t%s\t%s\n' "$name" "$src" "$ver" "$loc"; } | atomic_write "$SS_TOOLS_FILE"
}

tool_info() { [[ -f "$SS_TOOLS_FILE" ]] || return 0; awk -F'\t' -v n="$1" '$1==n{print; exit}' "$SS_TOOLS_FILE"; }

tool_forget() {
  [[ -f "$SS_TOOLS_FILE" ]] || return 0
  awk -F'\t' -v n="$1" '$1!=n' "$SS_TOOLS_FILE" | atomic_write "$SS_TOOLS_FILE"
}

# apt packages that supershell itself installed (so uninstall can offer to remove
# exactly those, never packages the user already had).
SS_APT_FILE="$SS_STATE/apt-installed"
apt_record() { mkdir -p "$SS_STATE"; grep -qx -- "$1" "$SS_APT_FILE" 2>/dev/null || echo "$1" >>"$SS_APT_FILE"; }
apt_recorded() { [[ -f "$SS_APT_FILE" ]] && cat "$SS_APT_FILE" || true; }
