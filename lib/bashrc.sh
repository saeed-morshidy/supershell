# shellcheck shell=bash
# The only change supershell makes to ~/.bashrc: one clearly marked block.

SS_BASHRC="${SUPERSHELL_BASHRC:-$HOME/.bashrc}"
SS_MARK_BEGIN="# >>> supershell >>>"
SS_MARK_END="# <<< supershell <<<"

bashrc_block_text() {
  local init="$SS_APP/shell/init.bash"
  init="${init/#$HOME/\$HOME}"
  cat <<EOF
$SS_MARK_BEGIN
# Managed by supershell — do not edit inside this block.
# Disable for one shell: SUPERSHELL_DISABLE=1 bash   |  Remove: supershell uninstall
[ -r "$init" ] && . "$init"
$SS_MARK_END
EOF
}

bashrc_block_count() {
  [[ -f "$SS_BASHRC" ]] || { echo 0; return; }
  awk -v b="$SS_MARK_BEGIN" 'index($0, b) == 1 { n++ } END { print n + 0 }' "$SS_BASHRC"
}

bashrc_has_block() { [[ "$(bashrc_block_count)" -ge 1 ]]; }

# Echo 1 if the file is non-empty and does not end in a newline.
_bashrc_missing_final_newline() {
  [[ -s "$1" ]] || { echo 0; return; }
  [[ "$(tail -c1 -- "$1" | od -An -c | tr -d ' ')" == '\n' ]] && echo 0 || echo 1
}

bashrc_install_block() {
  local target="$SS_BASHRC"
  if [[ -L "$target" ]]; then
    warn "~/.bashrc is a symlink (probably managed by a dotfiles tool) → $(readlink -f "$target")"
    if ! confirm "Edit the file it points to?" n; then
      warn "Not editing ~/.bashrc. Add these lines yourself to enable supershell:"
      bashrc_block_text >&2
      return 0
    fi
    target="$(readlink -f "$target")"
  fi
  if bashrc_has_block; then
    detail "~/.bashrc already has the supershell block — leaving it unchanged"
    return 0
  fi
  journal_track_file "$target"
  local nl; nl="$(_bashrc_missing_final_newline "$target")"
  {
    [[ "$nl" == 1 ]] && printf '\n'
    if [[ "$nl" == 1 ]]; then bashrc_block_text | sed "1s|\$| (added-newline)|"
    else bashrc_block_text; fi
  } >>"$target"
  ok "Added one source line to ~/.bashrc (backup kept)"
}

# Remove the block and restore the file byte-for-byte.
bashrc_remove_block() {
  local target="$SS_BASHRC"
  [[ -L "$target" ]] && target="$(readlink -f "$target")"
  [[ -f "$target" ]] || return 0
  grep -q -F -- "$SS_MARK_BEGIN" "$target" || return 0
  backup_file "$target" >/dev/null
  local strip_nl=0
  grep -q -F -- "$SS_MARK_BEGIN (added-newline)" "$target" && strip_nl=1
  local tmp; tmp="$(mktemp)"
  awk -v b="$SS_MARK_BEGIN" -v e="$SS_MARK_END" '
    index($0, b) == 1 { skip = 1; next }
    skip && $0 == e   { skip = 0; next }
    !skip             { print }
  ' "$target" >"$tmp"
  if [[ $strip_nl == 1 && -s "$tmp" ]]; then
    # remove the single trailing newline we had added
    local tmp2; tmp2="$(mktemp)"; head -c -1 -- "$tmp" >"$tmp2"; mv -f -- "$tmp2" "$tmp"
  fi
  cat -- "$tmp" >"$target"   # keep inode, owner and permissions
  rm -f -- "$tmp"
  ok "Removed the supershell block from ~/.bashrc"
}

# Lines in the user's own bashrc that would initialise the same tools twice.
bashrc_duplicate_inits() {
  [[ -f "$SS_BASHRC" ]] || return 0
  awk -v b="$SS_MARK_BEGIN" -v e="$SS_MARK_END" '
    index($0, b) == 1 { skip = 1; next }
    skip && $0 == e   { skip = 0; next }
    skip || /^[[:space:]]*#/ { next }
    /starship init|zoxide init|atuin init|fzf --bash|key-bindings\.bash|ble\.sh/ { printf "%d: %s\n", NR, $0 }
  ' "$SS_BASHRC"
}
