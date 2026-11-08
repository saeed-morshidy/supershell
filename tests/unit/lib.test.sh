# shellcheck shell=bash
# Unit tests for lib/*.sh

test_os_detects_ubuntu_2604_as_primary() {
  t_load_lib
  os_support_level; assert_eq "$?" 0
  assert_eq "$OS_ARCH" x86_64
}

test_os_2404_is_best_effort() {
  t_load_lib; t_os ubuntu 24.04 noble
  local lvl=0; os_support_level || lvl=$?
  assert_eq "$lvl" 1
}

test_os_debian_and_arm32_are_refused() {
  t_load_lib; t_os debian 13 trixie
  local lvl=0; os_support_level || lvl=$?; assert_eq "$lvl" 2
  t_os ubuntu 26.04 resolute; SUPERSHELL_ARCH=armv7l
  lvl=0; os_support_level || lvl=$?; assert_eq "$lvl" 2
}

test_os_aarch64_is_supported() {
  t_load_lib; SUPERSHELL_ARCH=arm64
  os_support_level; assert_eq "$OS_ARCH" aarch64
}

test_install_refuses_unsupported_os_without_force() {
  t_os fedora 42 ""
  local out; out="$(ss install --yes 2>&1)" && t_fail "should refuse"
  assert_contains "$out" "Unsupported system"
  assert_no_file "$HOME/.local/share/supershell/app"
}

test_bashrc_block_insert_is_idempotent_and_preserves_content() {
  t_load_lib; t_ubuntu_bashrc; cp "$HOME/.bashrc" "$T_TMP/orig"
  journal_begin test
  bashrc_install_block 2>/dev/null; bashrc_install_block 2>/dev/null
  journal_commit
  assert_eq "$(bashrc_block_count)" 1
  head -c "$(stat -c %s "$T_TMP/orig")" "$HOME/.bashrc" >"$T_TMP/prefix"
  assert_same_file "$T_TMP/prefix" "$T_TMP/orig"
}

test_bashrc_remove_restores_byte_for_byte() {
  t_load_lib; t_ubuntu_bashrc; cp "$HOME/.bashrc" "$T_TMP/orig"
  journal_begin t; bashrc_install_block 2>/dev/null; journal_commit
  bashrc_remove_block 2>/dev/null
  assert_same_file "$HOME/.bashrc" "$T_TMP/orig"
}

test_bashrc_without_final_newline_round_trips() {
  t_load_lib; printf 'alias x=y' >"$HOME/.bashrc"; cp "$HOME/.bashrc" "$T_TMP/orig"
  journal_begin t; bashrc_install_block 2>/dev/null; journal_commit
  assert_contains "$(cat "$HOME/.bashrc")" $'alias x=y\n# >>> supershell >>>'
  bashrc_remove_block 2>/dev/null
  assert_same_file "$HOME/.bashrc" "$T_TMP/orig"
}

test_bashrc_missing_is_created_and_removed_cleanly() {
  t_load_lib
  journal_begin t; bashrc_install_block 2>/dev/null; journal_commit
  assert_eq "$(bashrc_block_count)" 1
  bashrc_remove_block 2>/dev/null
  assert_eq "$(stat -c %s "$HOME/.bashrc")" 0
}

test_bashrc_symlink_is_not_edited_without_consent() {
  t_load_lib; mkdir -p "$HOME/dotfiles"; echo "# mine" >"$HOME/dotfiles/bashrc"
  ln -s "$HOME/dotfiles/bashrc" "$HOME/.bashrc"
  journal_begin t; bashrc_install_block 2>/dev/null; journal_commit
  assert_eq "$(cat "$HOME/dotfiles/bashrc")" "# mine"
  assert_eq "$(readlink "$HOME/.bashrc")" "$HOME/dotfiles/bashrc"
}

test_bashrc_detects_duplicate_tool_init() {
  t_load_lib; t_ubuntu_bashrc; echo 'eval "$(starship init bash)"' >>"$HOME/.bashrc"
  assert_contains "$(bashrc_duplicate_inits)" "starship init"
}

test_backup_and_restore() {
  t_load_lib; echo one >"$HOME/f"
  backup_file "$HOME/f" >/dev/null
  echo two >"$HOME/f"
  local id; id="$(basename "$SS_BACKUP_SESSION")"
  SS_BACKUP_SESSION="" backup_restore "$id" 2>/dev/null
  assert_eq "$(cat "$HOME/f")" one
}

test_journal_rollback_restores_and_removes() {
  t_load_lib; echo original >"$HOME/a"
  journal_begin t
  journal_track_file "$HOME/a"; echo changed >"$HOME/a"
  journal_track_file "$HOME/b"; echo new >"$HOME/b"
  journal_rollback 2>/dev/null
  assert_eq "$(cat "$HOME/a")" original
  assert_no_file "$HOME/b"
  assert_no_file "$SS_JOURNAL"
}

test_journal_blocks_new_run_until_repaired() {
  t_load_lib; journal_begin t
  local out; out="$( (journal_begin again) 2>&1)" && t_fail "should refuse"
  assert_contains "$out" "supershell repair"
}

test_safe_rm_refuses_paths_outside_supershell() {
  t_load_lib; mkdir -p "$HOME/precious"
  local out; out="$( (safe_rm "$HOME/precious") 2>&1)" && t_fail "should refuse"
  assert_file "$HOME/precious"
  ( safe_rm / ) 2>/dev/null && t_fail "must refuse /"
  return 0
}

test_config_set_validates() {
  t_load_lib; config_init_defaults
  config_set mode classic; assert_eq "$(config_get mode)" classic
  ( config_set mode fancy ) 2>/dev/null && t_fail "invalid value accepted"
  ( config_set nope x ) 2>/dev/null && t_fail "unknown key accepted"
  assert_eq "$(config_get devops_aliases)" off
}

test_manifest_expands_version() {
  t_load_lib
  assert_eq "$(manifest_get neovim version)" "$(awk '/^\[neovim\]/{f=1} f&&/^version/{print $3; exit}' "$T_REPO/manifest/tools.ini")"
  assert_contains "$(manifest_get neovim url.x86_64)" "/v$(manifest_get neovim version)/nvim-linux-x86_64.tar.gz"
  assert_eq "$(manifest_get blesh apt)" ""
}

test_every_manifest_tool_has_both_architectures() {
  t_load_lib
  local t
  for t in $(grep -oE '^\[[a-z-]+\]' "$T_REPO/manifest/tools.ini" | tr -d '[]'); do
    [[ "$(manifest_get "$t" version)" == system ]] && continue
    [[ -n "$(manifest_get "$t" url.x86_64)" ]] || t_fail "$t: no x86_64 url"
    [[ -n "$(manifest_get "$t" url.aarch64)" ]] || t_fail "$t: no aarch64 url"
    [[ "$(manifest_get "$t" url.x86_64)" == https://* ]] || t_fail "$t: url must be https"
  done
}

_fixture_release() { # tool version-file-name content
  local d="$T_TMP/fx-$1"; mkdir -p "$d/pkg/inner"
  printf '#!/bin/sh\necho %s\n' "$1" >"$d/pkg/inner/$1"; chmod +x "$d/pkg/inner/$1"
  tar -czf "$T_DL/$2" -C "$d/pkg" inner
}

_test_manifest() { # tool sha sums
  cat >"$T_TMP/m.ini" <<EOF2
[demo]
version = 1.0.0
url.x86_64 = https://example.invalid/demo-{version}.tar.gz
url.aarch64 = https://example.invalid/demo-{version}.tar.gz
sha256.x86_64 = $1
sums = $2
bins = demo
EOF2
  SS_MANIFEST="$T_TMP/m.ini"
}

test_release_with_pinned_checksum_installs() {
  t_load_lib; os_detect; _fixture_release demo demo-1.0.0.tar.gz
  _test_manifest "$(sha256sum "$T_DL/demo-1.0.0.tar.gz" | cut -d' ' -f1)" ""
  journal_begin t; install_release demo 2>/dev/null; journal_commit
  assert_eq "$("$HOME/.local/bin/demo")" demo
  assert_contains "$(tool_info demo)" $'release\t1.0.0'
}

test_release_with_wrong_checksum_is_rejected_and_nothing_installed() {
  t_load_lib; os_detect; _fixture_release demo demo-1.0.0.tar.gz
  _test_manifest "0000000000000000000000000000000000000000000000000000000000000000" ""
  local out; out="$( (journal_begin t; install_release demo) 2>&1)" && t_fail "should fail"
  assert_contains "$out" "Checksum mismatch"
  assert_no_file "$HOME/.local/bin/demo"
  assert_no_file "$HOME/.local/share/supershell/opt/demo/1.0.0"
  assert_no_file "$HOME/.cache/supershell/dl/demo-1.0.0.tar.gz"
}

test_release_verified_by_upstream_sums_warns() {
  t_load_lib; os_detect; _fixture_release demo demo-1.0.0.tar.gz
  (cd "$T_DL" && sha256sum demo-1.0.0.tar.gz >SUMS.txt)
  _test_manifest "" "https://example.invalid/SUMS.txt"
  local out; out="$( (journal_begin t; install_release demo; journal_commit) 2>&1)"
  assert_contains "$out" "upstream checksum file"
  assert_file "$HOME/.local/bin/demo"
}

test_release_without_any_checksum_is_refused() {
  t_load_lib; os_detect; _fixture_release demo demo-1.0.0.tar.gz
  _test_manifest "" ""
  local out; out="$( (journal_begin t; install_release demo) 2>&1)" && t_fail "should refuse"
  assert_contains "$out" "Refusing to install an unverified download"
  assert_no_file "$HOME/.local/bin/demo"
}

test_link_bin_never_clobbers_user_files() {
  t_load_lib; mkdir -p "$HOME/.local/bin"; echo "mine" >"$HOME/.local/bin/demo"
  link_bin /bin/true demo 2>/dev/null
  assert_eq "$(cat "$HOME/.local/bin/demo")" mine
}

test_apt_preferred_when_new_enough_else_release() {
  t_load_lib; os_detect
  journal_begin t
  install_tool zoxide 2>/dev/null
  assert_contains "$(tool_info zoxide)" $'\tapt\t'
  sed -i 's/^neovim .*/neovim 0.11.4-1 nvim/' "$T_APT/available"
  local out; out="$(install_tool neovim 2>&1)" && t_fail "release download expected (no fixture)"
  assert_contains "$out" "using the pinned release"
  journal_rollback 2>/dev/null
}

test_ubuntu_binary_names_get_friendly_links() {
  t_load_lib; os_detect
  journal_begin t; install_tool bat 2>/dev/null; install_tool fd 2>/dev/null; journal_commit
  assert_eq "$(readlink "$HOME/.local/bin/bat")" "$T_FAKE_BIN/batcat"
  assert_eq "$(readlink "$HOME/.local/bin/fd")" "$T_FAKE_BIN/fdfind"
}
