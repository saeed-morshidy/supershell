# shellcheck shell=bash
# core — prompt, fuzzy finder, smart cd, modern file tools.
MOD_DESC="Prompt (starship), fzf, zoxide, eza, bat, fd, ripgrep"
MOD_DEFAULT=yes
MOD_TOOLS="starship fzf zoxide eza bat fd ripgrep"
MOD_DEPS=""

read -r -a CORE_TOOLS <<<"$MOD_TOOLS"

# Segmented prompt styles: name:starship-preset[:palette]. Must match prompt_style in
# lib/state.sh. Each preset has config/starship/<preset>.overlay.toml.
CORE_PROMPT_STYLES=(
  pastel-powerline:pastel-powerline
  tokyo-night:tokyo-night
  gruvbox-rainbow:gruvbox-rainbow
  catppuccin-mocha:catppuccin-powerline:catppuccin_mocha
  catppuccin-macchiato:catppuccin-powerline:catppuccin_macchiato
  catppuccin-frappe:catppuccin-powerline:catppuccin_frappe
  catppuccin-latte:catppuccin-powerline:catppuccin_latte
)

mod_install() {
  local t
  for t in "${CORE_TOOLS[@]}"; do install_tool "$t"; done
}

# ---- the user's own prompt changes -------------------------------------------------
# ~/.config/supershell/prompt.toml is applied on top of every rendered style and its
# values win. supershell never writes to it. A file starship rejects is ignored (the
# style is used without it) and the reason is kept for `prompt apply` and `doctor`.
CORE_USER_PROMPT="$SS_CONFIG_DIR/prompt.toml"
CORE_PROMPT_ERR="$SS_STATE/prompt-error"

# starship prints config problems as warnings while drawing a prompt; none = valid.
# Each check gets its own STARSHIP_CACHE: starship prints a given warning only once per
# log session, so a shared one would hide the problem from every check after the first.
core_prompt_warnings() {
  local c; c="$(mktemp -d "$SS_CACHE/starship-check.XXXXXX")"
  (cd / && STARSHIP_CACHE="$c" STARSHIP_CONFIG="$1" STARSHIP_LOG=warn starship prompt 2>&1 >/dev/null) |
    sed 's/\x1b\[[0-9;]*m//g' | grep -v '^[[:space:]]*$' | head -3 || true   # none = normal
  rm -rf -- "$c"
}

# _core_layer <rendered file> <layer file> — merge the layer over the file (the layer's
# values win). Returns 1 and prints starship's message when the layer adds problems.
_core_layer() {
  local src="$1" layer="$2" warn
  awk -f "$CORE_MERGE" "$src" "$layer" >"$src.l"
  warn="$(core_prompt_warnings "$src.l")"
  # only what the LAYER adds counts (a preset may already warn on an older starship)
  if [[ "$warn" == "$(core_prompt_warnings "$src")" ]]; then mv -f -- "$src.l" "$src"; return 0; fi
  rm -f -- "$src.l"; printf '%s\n' "$warn"; return 1
}

core_write_prompt() {   # <rendered file> <style name>
  local src="$1" name="$2" custom warn
  # supershell's ready-made tweaks (prompt_custom = on), only for styles that have them
  custom="$CORE_STARSHIP_DIR/custom/$name.toml"
  # prompt_cap = on: the variant that keeps the round cap at the start of the line
  [[ "$(config_get prompt_cap)" == on && -f "${custom%.toml}.cap.toml" ]] && custom="${custom%.toml}.cap.toml"
  if [[ "$(config_get prompt_custom)" == on && -f "$custom" ]]; then
    warn="$(_core_layer "$src" "$custom")" || warn "custom prompt settings for $name not applied: ${warn%%$'\n'*}"
  fi
  if [[ -s "$CORE_USER_PROMPT" ]]; then
    if ! warn="$(_core_layer "$src" "$CORE_USER_PROMPT")"; then
      [[ -s "$CORE_PROMPT_ERR" ]] || printf '%s\n' "$warn" >"$CORE_PROMPT_ERR"
    fi
  fi
  atomic_write "$SS_CONFIG_DIR/starship-$name.toml" <"$src"
}

# Render the prompt configs. Designs and icons come from starship's own built-in
# presets (shipped inside the starship binary — nothing is downloaded); supershell
# only ADDS its few extras on top, never changing what a preset sets:
#   starship-pastel-powerline.toml preset + pastel-powerline.overlay.toml (Nerd icons, default)
#   starship-tokyo-night.toml      preset + tokyo-night.overlay.toml      (Nerd icons)
#   starship-gruvbox-rainbow.toml  preset + gruvbox-rainbow.overlay.toml  (Nerd icons)
#   starship-catppuccin-*.toml     catppuccin-powerline, one per flavour   (Nerd icons)
#   starship-nerd.toml             simple template + nerd-font-symbols    (Nerd icons)
#   starship-plain.toml            simple template + plain-text-symbols   (SSH, console)
core_render_starship() {
  have starship || return 0
  local dir="$SS_APP/config/starship" merge="$SS_APP/lib/toml-merge.awk" devops_off=true w style
  [[ -f "$dir/starship.toml.in" ]] || dir="$SS_ROOT/config/starship"
  [[ -f "$merge" ]] || merge="$SS_ROOT/lib/toml-merge.awk"
  module_is_installed devops && [[ "$(config_get devops)" == on ]] && devops_off=false
  w="$(mktemp -d "$SS_CACHE/prompt.XXXXXX")"
  CORE_MERGE="$merge" CORE_STARSHIP_DIR="$dir"; rm -f -- "$CORE_PROMPT_ERR"
  _dev() { sed "s/@DEVOPS_OFF@/$devops_off/g" "$1"; }

  for style in nerd plain; do
    local sym=nerd-font-symbols; [[ $style == plain ]] && sym=plain-text-symbols
    _dev "$dir/starship.toml.in" >"$w/base"
    if starship preset "$sym" >"$w/sym" 2>/dev/null; then
      awk -f "$merge" "$w/sym" "$w/base" >"$w/b2" && mv "$w/b2" "$w/base"
    fi
    awk -f "$merge" "$dir/fallback-$style.toml" "$w/base" >"$w/out" && core_write_prompt "$w/out" "$style"
  done

  # Segmented presets, as published, plus supershell's modules at the end of line 1
  # (before the preset's first line break, written `$line_break` or `\n`). Only the
  # modules a preset lacks are added. A flavour picks one of the preset's own palettes.
  local entry name preset pal mods extra
  rm -f -- "$SS_CONFIG_DIR/starship-powerline.toml"
  for entry in "${CORE_PROMPT_STYLES[@]}"; do
    IFS=: read -r name preset pal <<<"$entry"
    rm -f -- "$SS_CONFIG_DIR/starship-$name.toml"
    # stdout, not -o: starship >= 1.27 refuses to overwrite with -o
    starship preset "$preset" >"$w/p" 2>/dev/null || continue
    if [[ -n "$pal" ]]; then
      grep -q "^\[palettes\.$pal\]" "$w/p" && grep -q '^palette = ' "$w/p" || continue
      sed -i "s/^palette = .*/palette = '$pal'/" "$w/p"
    fi
    extra=""
    for mods in kubernetes cmd_duration jobs status; do
      grep -q "\\\$$mods\\b" "$w/p" || extra+="\$$mods"
    done
    if grep -q '\$line_break' "$w/p"; then
      sed -i "0,/\\\$line_break/s//${extra//\$/\\\$}\$line_break/" "$w/p"
    elif grep -q '\\n\$character' "$w/p"; then
      sed -i "0,/\\\\n\\\$character/s//${extra//\$/\\\$}\\\\n\$character/" "$w/p"
    elif grep -qx '"""' "$w/p"; then
      # a one-line preset (pastel-powerline): its format ends with a bare """ line
      sed -i "0,/^\"\"\"\$/s//${extra//\$/\\\$}\\\\n\$character\"\"\"/" "$w/p"
    else
      continue   # unknown layout in this starship version: keep the simple prompt
    fi
    # The one deliberate change to presets: supershell's segmented prompts are always
    # two lines (segments on top, typing below). pastel-powerline has no line break
    # (added above); catppuccin-powerline turns it off.
    awk '/^\[/{s=$0} s=="[line_break]" && /^disabled[ \t]*=[ \t]*true/{sub(/true/,"false")} {print}' "$w/p" >"$w/p2" && mv "$w/p2" "$w/p"
    _dev "$dir/$preset.overlay.toml" >"$w/ov"
    awk -f "$merge" "$w/ov" "$w/p" >"$w/out" && core_write_prompt "$w/out" "$name"
  done

  # supershell-theme: supershell's own theme file (no preset involved). Icons come from
  # starship's nerd-font-symbols preset (theme values win). Two renders: yours, and the
  # one root shells get (`supershell root on`) with the root palette.
  local theme="$dir/themes/supershell-theme.toml" pal variant
  [[ "$(config_get prompt_cap)" == on ]] && theme="$dir/themes/supershell-theme.cap.toml"
  if [[ -f "$theme" ]]; then
    starship preset nerd-font-symbols >"$w/sym" 2>/dev/null || : >"$w/sym"
    for variant in supershell-theme supershell-theme-root; do
      pal="$(config_get theme_colors)"
      if [[ "$variant" == *-root ]]; then
        pal="$(config_get theme_root_colors)"; [[ "$pal" == same ]] && pal="$(config_get theme_colors)"
      fi
      _dev "$theme" | sed "s/^palette = .*/palette = \"$pal\"/" >"$w/p"
      awk -f "$merge" "$w/sym" "$w/p" >"$w/p2"
      awk -f "$merge" "$dir/fallback-nerd.toml" "$w/p2" >"$w/out" && core_write_prompt "$w/out" "$variant"
    done
  fi
  unset -f _dev
  rm -rf -- "$w"
}

mod_apply() { core_render_starship; }

mod_remove() {
  local t
  for t in "${CORE_TOOLS[@]}"; do remove_tool "$t"; done
  rm -f -- "$SS_CONFIG_DIR"/starship-*.toml
  rm -rf -- "$SS_CACHE/init"
}

mod_doctor_prompt() {
  if [[ -s "$CORE_PROMPT_ERR" ]]; then
    check_warn "your ${CORE_USER_PROMPT/#$HOME/\~} is ignored: $(head -1 "$CORE_PROMPT_ERR") (fix it, then: supershell prompt apply)"
  elif [[ -f "$CORE_USER_PROMPT" ]]; then
    if [[ "$CORE_USER_PROMPT" -nt "$SS_CONFIG_DIR/starship-plain.toml" ]]; then
      check_warn "${CORE_USER_PROMPT/#$HOME/\~} changed since it was applied — run: supershell prompt apply"
    else check_ok "your prompt changes are applied (${CORE_USER_PROMPT/#$HOME/\~})"; fi
  fi
}

mod_doctor() {
  local t bin
  for t in starship fzf zoxide eza bat fd rg; do
    if have "$t"; then check_ok "$t $("$t" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
    else check_fail "$t not found (run: supershell install core)"; fi
  done
  if have fzf; then
    bin="$(fzf --version 2>/dev/null | awk '{print $1}')"
    version_ge "$bin" 0.48 2>/dev/null && check_ok "fzf supports --bash" || check_warn "fzf $bin is older than 0.48 (no 'fzf --bash' shell integration)"
  fi
  [[ -f "$SS_CONFIG_DIR/starship-plain.toml" ]] && check_ok "prompt config rendered" || check_fail "prompt config missing (run: supershell install core)"
  local ps; ps="$(config_get prompt_style)"
  if [[ "$ps" != simple ]]; then
    local what="starship preset"; [[ "$ps" == supershell-theme ]] && what="supershell's own theme, colours: $(config_get theme_colors), root: $(config_get theme_root_colors)"
    [[ -f "$SS_CONFIG_DIR/starship-$ps.toml" ]] && check_ok "prompt style: $ps ($what)" \
      || check_warn "prompt style '$ps' could not be rendered by this starship version — using the simple prompt"
  fi
  mod_doctor_prompt
  [[ -n "${STARSHIP_CONFIG:-}" && "$STARSHIP_CONFIG" != "$SS_CONFIG_DIR"/* ]] && check_warn "STARSHIP_CONFIG is set to your own file ($STARSHIP_CONFIG) — supershell's prompt is not used"
  return 0
}
