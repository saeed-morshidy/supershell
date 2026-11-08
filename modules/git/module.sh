# shellcheck shell=bash
# git — clearer diffs with delta. Adds one include line to ~/.gitconfig.
MOD_DESC="Readable git diffs (delta); one include line in ~/.gitconfig"
MOD_DEFAULT=yes
MOD_TOOLS="delta"
MOD_PKGS="git"
MOD_DEPS=""

GIT_INCLUDE="~/.config/supershell/git/delta.gitconfig"   # git expands ~ itself
GIT_GLOBAL="${GIT_CONFIG_GLOBAL:-$HOME/.gitconfig}"

_git_has_include() { grep -qxF -- "$GIT_INCLUDE" <<<"$(git config --global --get-all include.path 2>/dev/null)"; }

mod_install() {
  have git || { info "Installing git"; apt_update_once; run_root apt-get install -y -qq git; }
  install_tool delta
  mkdir -p "$SS_CONFIG_DIR/git"
  cp -- "$SS_APP/config/git/delta.gitconfig" "$SS_CONFIG_DIR/git/delta.gitconfig"
  _git_has_include && return 0
  local own_pager
  own_pager="$(git config --global --get core.pager 2>/dev/null || true)"
  if [[ -n "$own_pager" ]]; then
    warn "You already set core.pager='$own_pager' in ~/.gitconfig — keeping yours (delta not enabled)."
    detail "To use delta anyway: git config --global --add include.path '$GIT_INCLUDE'"
    return 0
  fi
  if confirm "Add one include line to ~/.gitconfig so 'git diff' uses delta? (backup kept)" y; then
    journal_track_file "$GIT_GLOBAL"
    run git config --global --add include.path "$GIT_INCLUDE"
    ok "Git diffs now use delta"
  else
    detail "Skipped. Enable later: git config --global --add include.path '$GIT_INCLUDE'"
  fi
}

mod_remove() {
  if _git_has_include; then
    backup_file "$GIT_GLOBAL" >/dev/null || true
    run git config --global --fixed-value --unset-all include.path "$GIT_INCLUDE" || true
    detail "removed the include line from ~/.gitconfig"
  fi
  rm -rf -- "$SS_CONFIG_DIR/git"
  remove_tool delta
}

mod_doctor() {
  check_cmd git "$(git --version 2>/dev/null | awk '{print $3}')"
  have delta && check_ok "delta $(delta --version 2>/dev/null | awk '{print $2}')" || check_fail "delta not found"
  if _git_has_include; then check_ok "~/.gitconfig includes the supershell delta settings"
  else check_warn "delta is not enabled in ~/.gitconfig (you may have your own pager)"; fi
  return 0
}
