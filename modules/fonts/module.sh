# shellcheck shell=bash
# fonts — the terminal font (from Ubuntu's archive), Arabic in fixed-width cells, and
# Nerd Font icons as a fallback (no patched fonts).
MOD_DESC="Terminal font with clean Arabic + icon glyphs (no patched fonts)"
MOD_DEFAULT=yes
MOD_TOOLS="nerd-symbols"
MOD_DEPS=""

# Supported fonts: setting|family|Ubuntu package|has Arabic itself.
# Fonts without Arabic get it from DejaVu Sans Mono (fixed width) via fontconfig, so
# Arabic never falls back to a proportional font.
FONTS_SUPPORTED=(
  "dejavu-sans-mono|DejaVu Sans Mono|fonts-dejavu-core|yes"
  "cascadia-code|Cascadia Code|fonts-cascadia-code|yes"
  "jetbrains-mono|JetBrains Mono|fonts-jetbrains-mono|no"
  "fira-code|Fira Code|fonts-firacode|no"
  "ibm-plex-mono|IBM Plex Mono|fonts-ibm-plex|no"
  "ubuntu-sans-mono|Ubuntu Sans Mono|fonts-ubuntu|no"
)
_font_field() {   # <setting> <field 2..4>
  local l; for l in "${FONTS_SUPPORTED[@]}"; do
    [[ "${l%%|*}" == "$1" ]] && { cut -d'|' -f"$2" <<<"$l"; return 0; }
  done; return 1
}
FONT_NAME="$(config_get font)"
FONT_FAMILY="$(_font_field "$FONT_NAME" 2 || echo "DejaVu Sans Mono")"
FONT_PKG="$(_font_field "$FONT_NAME" 3 || echo fonts-dejavu-core)"
# DejaVu Sans Mono is always installed: it is the Arabic fallback for the others.
MOD_PKGS="fontconfig fonts-dejavu-core"
[[ "$FONT_PKG" != fonts-dejavu-core ]] && MOD_PKGS+=" $FONT_PKG"

FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/supershell"
FC_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/conf.d/60-supershell-symbols.conf"
FONT_MAIN="$FONT_FAMILY $(config_get font_size)"   # supershell font <name> · config set font_size N
PTYXIS_SCHEMA="org.gnome.Ptyxis"
PTYXIS_PREV="$SS_STATE/ptyxis-font.prev"
PTYXIS_SET="$SS_STATE/ptyxis-font.set"   # the font supershell itself last set

_ptyxis_available() { have gsettings && grep -qx font-name <<<"$(gsettings list-keys "$PTYXIS_SCHEMA" 2>/dev/null)"; }

# Install one Ubuntu font package if it is missing (normally already done by the
# single apt batch at the start of `supershell install`).
_font_pkg() {
  apt_installed_version "$1" >/dev/null && return 0
  apt_update_once
  run_root apt-get install -y -qq "$1" && { journal_add apt "$1"; apt_record "$1"; }
}

# Set the Ptyxis font and remember that supershell set it.
_ptyxis_set_font() {
  run gsettings set "$PTYXIS_SCHEMA" font-name "$1" && printf '%s\n' "$1" >"$PTYXIS_SET"
}

# Is the Ptyxis font still the one supershell set? Then supershell may change it; a
# font the user picked afterwards (even a supported one) is left alone.
_ptyxis_font_is_ours() {
  local cur="$1" l fam
  if [[ -s "$PTYXIS_SET" ]]; then [[ "$cur" == "'$(<"$PTYXIS_SET")'" ]]; return; fi
  # installs from before the record existed: any supported family at any size
  for l in "${FONTS_SUPPORTED[@]}"; do
    fam="$(cut -d'|' -f2 <<<"$l")"
    [[ "$cur" =~ ^\'"$fam"\ [0-9]+\'$ ]] && return 0
  done
  return 1
}

mod_install() {
  _font_pkg fonts-dejavu-core
  _font_pkg "$FONT_PKG"
  have fc-cache || { apt_update_once; run_root apt-get install -y -qq fontconfig; }

  install_tool nerd-symbols
  local src; src="$SS_OPT/nerd-symbols/$(manifest_get nerd-symbols version)"
  [[ -d "$FONT_DIR" ]] || journal_add absent "$FONT_DIR"
  mkdir -p "$FONT_DIR"
  if [[ "$SS_DRY_RUN" != 1 ]]; then
    find "$src" -maxdepth 2 -name 'SymbolsNerdFont*.ttf' -exec cp -f -- {} "$FONT_DIR/" \;
  fi
  install_config "$SS_APP/config/fontconfig/60-supershell-symbols.conf" "$FC_CONF"
  run fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
  config_set nerd_font_installed yes

  if _ptyxis_available; then
    local cur_sys cur_font
    cur_sys="$(gsettings get "$PTYXIS_SCHEMA" use-system-font 2>/dev/null || echo true)"
    cur_font="$(gsettings get "$PTYXIS_SCHEMA" font-name 2>/dev/null || echo "''")"
    if [[ "$cur_font" == "'$FONT_MAIN'" && "$cur_sys" == false ]]; then
      detail "Ptyxis already uses $FONT_MAIN"
    elif confirm "Set the terminal (Ptyxis) font to $FONT_MAIN? (previous setting saved)" y; then
      [[ -f "$PTYXIS_PREV" ]] || printf 'use-system-font=%s\nfont-name=%s\n' "$cur_sys" "$cur_font" >"$PTYXIS_PREV"
      run gsettings set "$PTYXIS_SCHEMA" use-system-font false
      _ptyxis_set_font "$FONT_MAIN"
      ok "Ptyxis font: $FONT_MAIN"
    fi
  else
    detail "Ptyxis not detected — set your terminal font to '$FONT_MAIN' yourself (docs/arabic.md)"
  fi
}

mod_remove() {
  if [[ -f "$PTYXIS_PREV" ]] && _ptyxis_available; then
    local sys font
    sys="$(sed -n 's/^use-system-font=//p' "$PTYXIS_PREV")"
    font="$(sed -n 's/^font-name=//p' "$PTYXIS_PREV")"
    gsettings set "$PTYXIS_SCHEMA" use-system-font "${sys:-true}" || true
    font="${font#\'}"; font="${font%\'}"
    [[ -n "$font" ]] && gsettings set "$PTYXIS_SCHEMA" font-name "$font" || true
    rm -f -- "$PTYXIS_PREV" "$PTYXIS_SET"
    detail "restored your previous Ptyxis font setting"
  fi
  rm -rf -- "$FONT_DIR"
  remove_config "$FC_CONF"
  have fc-cache && fc-cache -f >/dev/null 2>&1 || true
  config_set nerd_font_installed no
  remove_tool nerd-symbols
}

# `supershell font <name>` / `config set font_size N`: install the font package if
# needed and update Ptyxis — only while it still uses a font supershell set.
mod_apply() {
  [[ "$SS_DRY_RUN" == 1 ]] && return 0
  _font_pkg "$FONT_PKG"
  [[ -f "$PTYXIS_PREV" ]] && _ptyxis_available || return 0
  local cur; cur="$(gsettings get "$PTYXIS_SCHEMA" font-name 2>/dev/null)"
  [[ "$cur" == "'$FONT_MAIN'" ]] && return 0
  _ptyxis_font_is_ours "$cur" || return 0
  _ptyxis_set_font "$FONT_MAIN"
}

mod_doctor() {
  if have fc-list; then
    grep -q "Symbols Nerd Font" <<<"$(fc-list 2>/dev/null)" && check_ok "icon font (Symbols Nerd Font) installed" || check_fail "Symbols Nerd Font not found by fontconfig"
    grep -qx "$FONT_FAMILY" <<<"$(fc-list : family 2>/dev/null | tr ',' '\n')" \
      && check_ok "terminal font $FONT_FAMILY installed" || check_fail "font $FONT_FAMILY not installed (supershell install fonts)"
    grep -q "DejaVu Sans Mono" <<<"$(fc-list ':lang=ar' family 2>/dev/null)" && check_ok "DejaVu Sans Mono has Arabic glyphs" || check_warn "DejaVu Sans Mono with Arabic not found"
    if have fc-match; then
      # Arabic must come from the font itself or a fixed-width fallback
      local ar; ar="$(fc-match "$FONT_FAMILY:charset=0627" family 2>/dev/null)"
      if [[ "$ar" == "$FONT_FAMILY" || "$ar" == "DejaVu Sans Mono" ]]; then check_ok "Arabic in $FONT_FAMILY comes from $ar (fixed width)"
      else check_warn "Arabic in $FONT_FAMILY falls back to '$ar', which is not fixed-width (check ${FC_CONF/#$HOME/\~})"; fi
    fi
  fi
  if _ptyxis_available; then
    local f; f="$(gsettings get "$PTYXIS_SCHEMA" font-name 2>/dev/null)"
    [[ "$(gsettings get "$PTYXIS_SCHEMA" use-system-font 2>/dev/null)" == false ]] && check_ok "Ptyxis font: $f" || check_warn "Ptyxis uses the system font (may lack Arabic glyphs)"
  fi
  return 0
}
