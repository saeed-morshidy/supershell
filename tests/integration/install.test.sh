# shellcheck shell=bash
# End-to-end flows through the real CLI, with stubbed apt/sudo/curl.

test_fresh_install_defaults() {
  t_ubuntu_bashrc; cp "$HOME/.bashrc" "$T_TMP/orig"
  local out; out="$(ss install --yes 2>&1)" || t_fail "install failed: $out"
  assert_contains "$out" "Done."
  for m in core git editor fonts devops; do
    grep -qx "$m" "$HOME/.local/state/supershell/modules" || t_fail "module $m not recorded"
  done
  assert_file "$HOME/.local/share/supershell/app/shell/init.bash"
  assert_file "$HOME/.local/bin/supershell"
  assert_file "$HOME/.config/supershell/starship-nerd.toml"
  assert_file "$HOME/.config/supershell/starship-plain.toml"
  assert_file "$HOME/.config/supershell/starship-gruvbox-rainbow.toml"
  assert_file "$HOME/.config/supershell-nvim/init.lua"
  assert_file "$HOME/.local/share/fonts/supershell/SymbolsNerdFontMono-Regular.ttf"
  assert_no_file "$HOME/.local/state/supershell/journal"
  # only the block was appended
  head -c "$(stat -c %s "$T_TMP/orig")" "$HOME/.bashrc" | cmp -s - "$T_TMP/orig" || t_fail ".bashrc prefix changed"
  assert_eq "$(grep -c 'supershell' "$HOME/.bashrc")" 5
}

test_install_selected_modules_only() {
  ss install core --yes >/dev/null 2>&1 || t_fail "install core failed"
  assert_eq "$(cat "$HOME/.local/state/supershell/modules")" core
  assert_no_file "$HOME/.config/supershell-nvim"
}

test_dependencies_are_pulled_in() {
  ss install lazygit --yes >/dev/null 2>&1 || t_fail "install lazygit failed"
  grep -qx git "$HOME/.local/state/supershell/modules" || t_fail "dependency 'git' was not installed"
}

test_repeated_install_is_idempotent() {
  t_ubuntu_bashrc
  ss install --yes >/dev/null 2>&1 || t_fail "first install failed"
  cp "$HOME/.bashrc" "$T_TMP/after1"
  ss install --yes >/dev/null 2>&1 || t_fail "second install failed"
  assert_same_file "$HOME/.bashrc" "$T_TMP/after1"
  assert_eq "$(grep -c '^# >>> supershell >>>' "$HOME/.bashrc")" 1
  assert_eq "$(git config --global --get-all include.path | grep -c supershell)" 1
}

test_missing_dependency_failure_rolls_back() {
  t_ubuntu_bashrc; cp "$HOME/.bashrc" "$T_TMP/orig"
  local out; out="$(T_APT_FAIL=1 ss install --yes 2>&1)" && t_fail "should fail when apt fails"
  assert_contains "$out" "Rollback complete"
  assert_same_file "$HOME/.bashrc" "$T_TMP/orig"
  assert_no_file "$HOME/.local/share/supershell/app"
  assert_no_file "$HOME/.local/state/supershell/journal"
}

test_failure_in_later_module_rolls_back_everything() {
  t_ubuntu_bashrc; cp "$HOME/.bashrc" "$T_TMP/orig"
  local out; out="$(SUPERSHELL_TEST_FAIL_AT=fonts ss install --yes 2>&1)" && t_fail "should fail"
  assert_contains "$out" "simulated failure in fonts"
  assert_same_file "$HOME/.bashrc" "$T_TMP/orig"
  assert_no_file "$HOME/.config/supershell-nvim/init.lua"
  assert_no_file "$HOME/.local/share/supershell-nvim"   # plugins downloaded by this run
  assert_eq "$(git config --global --get-all include.path 2>/dev/null | grep -c supershell)" 0
  assert_eq "$(cat "$HOME/.local/state/supershell/modules" 2>/dev/null)" ""
}

test_interrupted_install_is_detected_and_repaired() {
  t_ubuntu_bashrc; cp "$HOME/.bashrc" "$T_TMP/orig"
  # Simulate power loss in the middle of a run: kill -9 gives traps no chance.
  SUPERSHELL_TEST_HANG_AT=git ss install core git --yes >/dev/null 2>&1 &
  local pid=$! i
  for i in $(seq 1 300); do grep -qx core "$HOME/.local/state/supershell/modules" 2>/dev/null && break; sleep 0.05; done
  # SIGKILL the whole process tree, parents before children, so nothing can react.
  local tree="$pid" frontier="$pid" next p
  while [[ -n "$frontier" ]]; do
    next=""; for p in $frontier; do next+=" $(pgrep -P "$p" || true)"; done
    frontier="$(echo $next)"; tree+=" $frontier"
  done
  kill -9 $tree 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  assert_file "$HOME/.local/state/supershell/journal"
  local out; out="$(ss install --yes 2>&1)" && t_fail "must refuse while a journal exists"
  assert_contains "$out" "supershell repair"
  assert_file "$HOME/.local/state/supershell/journal"   # the refusal must not consume it
  ss repair >/dev/null 2>&1
  assert_same_file "$HOME/.bashrc" "$T_TMP/orig"
  assert_no_file "$HOME/.local/state/supershell/journal"
  assert_eq "$(cat "$HOME/.local/state/supershell/modules" 2>/dev/null)" ""
  ss install core --yes >/dev/null 2>&1 || t_fail "install after repair failed"
}

test_offline_install_fails_cleanly() {
  local out; out="$(T_OFFLINE=1 ss install fonts --yes 2>&1)" && t_fail "should fail offline"
  assert_contains "$out" "Download failed"
  assert_contains "$out" "stalled"
  # downloads must never be able to hang forever
  assert_contains "$(grep '^curl' "$T_APT/log" | head -1)" "--speed-time"
  assert_contains "$(grep '^curl' "$T_APT/log" | head -1)" "--max-time"
  assert_no_file "$HOME/.local/share/fonts/supershell"
  assert_no_file "$HOME/.local/state/supershell/journal"
}

test_uninstall_restores_bashrc_and_removes_everything() {
  t_ubuntu_bashrc; cp "$HOME/.bashrc" "$T_TMP/orig"
  git config --global core.editor vim; cp "$HOME/.gitconfig" "$T_TMP/gitorig"
  ss install --yes >/dev/null 2>&1 || t_fail install
  ss uninstall --yes --purge-packages >/dev/null 2>&1 || t_fail uninstall
  assert_same_file "$HOME/.bashrc" "$T_TMP/orig"
  assert_eq "$(git config --global --get core.editor)" vim
  assert_eq "$(git config --global --get-all include.path 2>/dev/null | grep -c supershell)" 0
  assert_no_file "$HOME/.local/share/supershell/app"
  assert_no_file "$HOME/.local/bin/supershell"
  assert_no_file "$HOME/.config/supershell-nvim"
  assert_no_file "$HOME/.local/share/fonts/supershell"
  assert_no_file "$HOME/.config/fontconfig/conf.d/60-supershell-symbols.conf"
  assert_eq "$(cat "$T_APT/installed")" ""
  assert_file "$HOME/.local/state/supershell/backups"   # kept unless --purge
  # Ptyxis font restored
  assert_contains "$(cat "$T_TMP/gsettings")" "font-name='Monospace 11'"
}

test_uninstall_keeps_preexisting_apt_packages() {
  echo "zoxide 0.9.8-1" >>"$T_APT/installed"; cp "$T_REPO/tests/stubs/fake-tool" "$T_FAKE_BIN/zoxide"
  ss install core --yes >/dev/null 2>&1 || t_fail install
  ss uninstall --yes --purge-packages >/dev/null 2>&1 || t_fail uninstall
  grep -q '^zoxide ' "$T_APT/installed" || t_fail "user's own zoxide package was removed"
}

test_reinstall_after_uninstall() {
  ss install --yes >/dev/null 2>&1 || t_fail install
  ss uninstall --yes >/dev/null 2>&1 || t_fail uninstall
  ss install --yes >/dev/null 2>&1 || t_fail reinstall
  assert_eq "$(grep -c '^# >>> supershell >>>' "$HOME/.bashrc")" 1
}

test_user_edited_config_is_never_overwritten_or_deleted() {
  mkdir -p "$HOME/.config/supershell-nvim"; echo "-- my own" >"$HOME/.config/supershell-nvim/init.lua"
  ss install editor --yes >/dev/null 2>&1 || t_fail install
  assert_eq "$(cat "$HOME/.config/supershell-nvim/init.lua")" "-- my own"
  assert_file "$HOME/.config/supershell-nvim/init.lua.supershell"
  ss remove editor --yes >/dev/null 2>&1
  assert_eq "$(cat "$HOME/.config/supershell-nvim/init.lua")" "-- my own"
}

test_existing_user_pager_is_respected() {
  git config --global core.pager "less -S"
  ss install git --yes >/dev/null 2>&1 || t_fail install
  assert_eq "$(git config --global --get core.pager)" "less -S"
  assert_eq "$(git config --global --get-all include.path 2>/dev/null | grep -c supershell)" 0
}

test_restore_brings_back_a_backup() {
  t_ubuntu_bashrc; cp "$HOME/.bashrc" "$T_TMP/orig"
  ss install core --yes >/dev/null 2>&1 || t_fail install
  local id; id="$(ss restore --list 2>/dev/null | awk 'NR>1 && /bashrc/ {print $1; exit}')"
  [[ -n "$id" ]] || t_fail "no backup listed"
  ss restore "$id" --yes >/dev/null 2>&1
  assert_same_file "$HOME/.bashrc" "$T_TMP/orig"
}

test_doctor_healthy_and_detects_problems() {
  ss install core devops --yes >/dev/null 2>&1 || t_fail install
  local out; out="$(ss doctor 2>&1)" || t_fail "doctor reported problems on a healthy install: $out"
  assert_contains "$out" "interactive bash starts silently"
  sed -i '/supershell/d' "$HOME/.bashrc"
  out="$(ss doctor 2>&1)" && t_fail "doctor should fail without the block"
  assert_contains "$out" "no supershell block"
}

test_dry_run_changes_nothing() {
  t_ubuntu_bashrc; cp "$HOME/.bashrc" "$T_TMP/orig"
  local out; out="$(ss install core editor --dry-run --yes 2>&1)" || t_fail "dry-run failed: $out"
  assert_contains "$out" "starship"
  assert_contains "$out" "apt"
  assert_eq "$(cat "$T_APT/installed")" ""
  assert_same_file "$HOME/.bashrc" "$T_TMP/orig"
  assert_no_file "$HOME/.local/share/supershell"
  assert_no_file "$HOME/.local/state/supershell"
}

test_refuses_root_without_flag() {
  [[ $EUID -eq 0 ]] || t_skip "needs to run as root to test the root guard"
  local out; out="$("$T_REPO/supershell" install --yes </dev/null 2>&1)" && t_fail "should refuse root"
  assert_contains "$out" "normal user"
}

test_unknown_module_is_an_error() {
  local out; out="$(ss install corr --yes 2>&1)" && t_fail "typo accepted"
  assert_contains "$out" "Unknown module 'corr'"
}

test_unverified_release_aborts_and_rolls_back() {
  # Helix has no Ubuntu package, no pinned hash and no upstream checksum file.
  if grep -A5 '^\[helix\]' "$T_REPO/manifest/tools.ini" | grep -qE '^sha256.x86_64 = [0-9a-f]{64}'; then
    t_skip "helix is pinned now"
  fi
  local v; v="$(awk '/^\[helix\]/{f=1} f&&/^version/{print $3; exit}' "$T_REPO/manifest/tools.ini")"
  mkdir -p "$T_TMP/h/helix-$v-x86_64-linux"; echo "#!/bin/sh" >"$T_TMP/h/helix-$v-x86_64-linux/hx"
  tar -cJf "$T_DL/helix-$v-x86_64-linux.tar.xz" -C "$T_TMP/h" "helix-$v-x86_64-linux"
  local out; out="$(ss install helix --yes 2>&1)" && t_fail "must refuse unverified helix"
  assert_contains "$out" "Refusing to install an unverified download"
  assert_no_file "$HOME/.local/state/supershell/journal"
  assert_eq "$(cat "$HOME/.local/state/supershell/modules" 2>/dev/null)" ""
}

test_suggestions_are_part_of_the_default_install() {
  # ble.sh (grey suggestions as you type) comes from Ubuntu's package, in the one apt batch
  t_ubuntu_bashrc
  ss install --yes >/dev/null 2>&1 || t_fail "install failed"
  grep -qx plus "$HOME/.local/state/supershell/modules" || t_fail "plus not installed by default"
  assert_contains "$(grep '^apt-get install' "$T_APT/log")" "ble.sh"
  assert_eq "$(grep -c '^apt-get install' "$T_APT/log")" 1 "one apt batch"
  if grep -q 'akinomyoga' "$T_APT/log"; then t_fail "ble.sh must not be downloaded"; fi
  t_ibash 'echo "$BLE_VERSION/$SS_STUB_BLE_ATTACHED"'; assert_eq "$T_OUT" "0.4-stub/1"
  assert_contains "$(ss doctor 2>&1)" "ble.sh at"
}

test_no_unverified_fallback_when_ubuntu_lacks_ble_sh() {
  sed -i '/^ble.sh /d' "$T_APT/available"   # e.g. an Ubuntu release without the package
  local out; out="$(ss install plus --yes 2>&1)" && t_fail "must refuse"
  assert_contains "$out" "needs the Ubuntu package 'ble.sh'"
  if grep -q '^curl' "$T_APT/log" 2>/dev/null; then t_fail "nothing may be downloaded"; fi
  assert_no_file "$HOME/.local/state/supershell/journal"
}

test_ubuntu_packages_installed_in_one_batch() {
  ss install --yes >/dev/null 2>&1 || t_fail install
  assert_eq "$(grep -c '^apt-get install' "$T_APT/log")" 1 "expected exactly one apt-get install for all tools"
  assert_contains "$(grep '^apt-get install' "$T_APT/log")" "starship"
  assert_contains "$(grep '^apt-get install' "$T_APT/log")" "neovim"
}

test_predownloaded_file_is_reused_without_network() {
  mkdir -p "$HOME/.cache/supershell/dl"
  cp "$T_DL/NerdFontsSymbolsOnly.tar.xz" "$HOME/.cache/supershell/dl/"
  rm -f "$T_DL/NerdFontsSymbolsOnly.tar.xz"   # the "network" no longer has it
  local out; out="$(ss install fonts --yes 2>&1)" || t_fail "install with cached file failed: $out"
  assert_contains "$out" "using "
  assert_file "$HOME/.local/share/fonts/supershell/SymbolsNerdFontMono-Regular.ttf"
  ! grep -q 'NerdFontsSymbolsOnly' "$T_APT/log" || t_fail "curl must not be called for a cached file"
}

test_tampered_predownloaded_file_is_rejected() {
  mkdir -p "$HOME/.cache/supershell/dl"
  echo "tampered" >"$HOME/.cache/supershell/dl/NerdFontsSymbolsOnly.tar.xz"
  local out; out="$(ss install fonts --yes 2>&1)" && t_fail "tampered file must be rejected"
  assert_contains "$out" "Checksum mismatch"
  assert_no_file "$HOME/.cache/supershell/dl/NerdFontsSymbolsOnly.tar.xz"
  assert_no_file "$HOME/.local/share/fonts/supershell"
}

test_reinstall_does_not_complain_about_own_link() {
  ss install core --yes >/dev/null 2>&1 || t_fail "first install failed"
  local out; out="$(ss install core --yes 2>&1)" || t_fail "second install failed: $out"
  assert_not_contains "$out" "leaving it alone"
}

test_slow_plugin_download_leaves_no_half_cloned_plugins() {
  local out pack="$HOME/.local/share/supershell-nvim/site/pack/core/opt"
  # a plugin the user already has (complete checkout) must survive
  mkdir -p "$pack/mine" && git -C "$pack/mine" init -q && echo x >"$pack/mine/f" &&
    git -C "$pack/mine" add f && git -C "$pack/mine" -c user.email=t@t commit -qm x
  out="$(T_NVIM_SLOW=1 ss install editor --yes 2>&1)" || t_fail "a slow plugin download must not fail the install: $out"
  assert_contains "$out" "gave up after"
  assert_no_file "$pack/mini.nvim"
  assert_file "$pack/mine/f"
  grep -qx editor "$HOME/.local/state/supershell/modules" || t_fail "editor not recorded"
}

test_doctor_finds_icon_font_on_a_big_font_list() {
  # real desktops list thousands of fonts; `fc-list | grep -q` under pipefail failed there
  ss install fonts git --yes >/dev/null 2>&1 || t_fail install
  local out; out="$(ss doctor 2>&1)" || t_fail "doctor reported problems: $out"
  assert_contains "$out" "icon font (Symbols Nerd Font) installed"
  assert_contains "$out" "DejaVu Sans Mono has Arabic glyphs"
  assert_contains "$out" "git $(git --version | awk '{print $3}')"
}

test_predownloaded_file_survives_a_rollback_and_is_cleaned_after_success() {
  local f="$HOME/.cache/supershell/dl/NerdFontsSymbolsOnly.tar.xz"
  mkdir -p "${f%/*}"; cp "$T_DL/NerdFontsSymbolsOnly.tar.xz" "$f"
  SUPERSHELL_TEST_FAIL_AT=devops ss install fonts devops --yes >/dev/null 2>&1 && t_fail "should fail"
  assert_file "$f"   # still there for the next attempt
  ss install fonts --yes >/dev/null 2>&1 || t_fail "second attempt failed"
  assert_no_file "$f"
}

test_font_size_setting_updates_only_the_font_supershell_set() {
  ss install fonts --yes >/dev/null 2>&1 || t_fail install
  assert_contains "$(cat "$T_TMP/gsettings")" "font-name='Cascadia Code NF 14'"   # default font and size
  ss config set font_size 10 >/dev/null 2>&1 || t_fail "config set failed"
  assert_contains "$(cat "$T_TMP/gsettings")" "font-name='Cascadia Code NF 10'"
  # the user picks another font later: supershell must leave it alone
  gsettings set org.gnome.Ptyxis font-name 'Fira Code 13'
  ss config set font_size 14 >/dev/null 2>&1 || t_fail "config set failed"
  assert_contains "$(cat "$T_TMP/gsettings")" "font-name='Fira Code 13'"
}

test_font_choice_is_part_of_the_install() {
  # --font joins the single apt batch, and Ptyxis gets that font at the default size
  ss install fonts --font=jetbrains-mono --yes >/dev/null 2>&1 || t_fail "install failed"
  assert_eq "$(grep -c '^apt-get install' "$T_APT/log")" 1 "expected one apt batch"
  assert_contains "$(grep '^apt-get install' "$T_APT/log")" "fonts-jetbrains-mono"
  assert_contains "$(cat "$T_TMP/gsettings")" "font-name='JetBrains Mono 14'"
  # Arabic comes from a fixed-width font, icons from the Nerd Font: both strong fallbacks
  local fc="$HOME/.config/fontconfig/conf.d/60-supershell-symbols.conf"
  assert_contains "$(grep -A3 '<string>JetBrains Mono</string>' "$fc")" '<string>DejaVu Sans Mono</string>'
  assert_contains "$(grep -A3 '<string>JetBrains Mono</string>' "$fc")" 'binding="strong"'
  if grep -q 'binding="weak"' "$fc"; then t_fail "weak binding lets other fonts win"; fi
  local out; out="$(ss doctor 2>&1)" || t_fail "doctor: $out"
  assert_contains "$out" "terminal font JetBrains Mono installed"
  assert_contains "$out" "Arabic in JetBrains Mono comes from DejaVu Sans Mono (fixed width)"
  out="$(T_FC_ARABIC_PROPORTIONAL=1 ss doctor 2>&1)"; assert_contains "$out" "not fixed-width"
}

test_font_command_switches_and_installs_the_package() {
  ss install core fonts --yes >/dev/null 2>&1 || t_fail "install failed"
  assert_contains "$(cat "$T_TMP/gsettings")" "font-name='Cascadia Code NF 14'"   # default font
  : >"$T_APT/log"
  local out
  out="$(ss font jetbrains-mono 2>&1)" || t_fail "font jetbrains-mono failed"
  assert_contains "$(cat "$T_APT/log")" "fonts-jetbrains-mono"      # package installed on demand
  assert_contains "$(cat "$T_TMP/gsettings")" "font-name='JetBrains Mono 14'"
  assert_contains "$(ss font 2>&1)" "font: jetbrains-mono"
  # the bar's drawn rounded ends fit Cascadia's line: other fonts get a note, and doctor
  assert_contains "$out" "rounded ends are drawn for Cascadia Code NF"
  assert_contains "$(ss font 2>&1)" "bar ends: may step"
  assert_contains "$(ss doctor 2>&1)" "a 1px step can show"
  ss theme ends square >/dev/null 2>&1                              # square ends: nothing to say
  assert_not_contains "$(ss font fira-code 2>&1)" "rounded ends are drawn"
  ss theme ends rounded >/dev/null 2>&1
  assert_not_contains "$(ss font dejavu-sans-mono 2>&1)" "rounded ends are drawn"   # measured: fits
  ss font cascadia-code >/dev/null 2>&1
  assert_not_contains "$(ss doctor 2>&1)" "a 1px step can show"
  assert_contains "$(ss doctor 2>&1)" "prompt bar ends (Supershell Ends) installed"
  # a font the user picked in Ptyxis afterwards is left alone — even a supported one
  gsettings set org.gnome.Ptyxis font-name 'JetBrains Mono 11'
  ss font ubuntu-sans-mono >/dev/null 2>&1
  assert_contains "$(cat "$T_TMP/gsettings")" "font-name='JetBrains Mono 11'"
  ss font comic-sans >/dev/null 2>&1 && t_fail "unknown font must be refused"
  return 0
}

test_installed_tools_are_found_when_local_bin_is_not_on_path() {
  # Fresh servers / `su -c` / CI: ~/.local/bin is not on PATH yet, but release tools
  # are linked there. The prompt must still be rendered (found by the e2e job).
  ss install core --yes >/dev/null 2>&1 || t_fail "install failed"
  mkdir -p "$HOME/.local/bin"; mv "$T_FAKE_BIN/starship" "$HOME/.local/bin/starship"
  rm -f "$HOME"/.config/supershell/starship-*.toml
  local p; p="$(tr ':' '\n' <<<"$PATH" | grep -vx "$HOME/.local/bin" | paste -sd:)"
  : >"$T_TMP/calls"
  PATH="$p" "$T_REPO/supershell" prompt apply </dev/null >/dev/null 2>&1 || t_fail "prompt apply failed"
  # the installed starship (the fake one records its calls) did the rendering — not
  # nothing, and not some other starship that happens to be in /usr/bin
  assert_contains "$(cat "$T_TMP/calls")" "starship preset"
  assert_file "$HOME/.config/supershell/starship-plain.toml"
  assert_file "$HOME/.config/supershell/starship-pastel-powerline.toml"
}

test_doctor_never_downloads_editor_plugins() {
  # Without plugins, starting nvim would make vim.pack download them (found by e2e).
  ss install editor --yes >/dev/null 2>&1 || t_fail "install failed"
  rm -rf "$HOME/.local/share/supershell-nvim/site"
  : >"$T_TMP/calls"
  local out; out="$(ss doctor 2>&1)"
  assert_contains "$out" "editor plugins not installed yet"
  assert_not_contains "$out" "profile error"
  if grep -q '^nvim --headless +lua' "$T_TMP/calls"; then t_fail "doctor started nvim without plugins"; fi
}

test_root_prompt_uses_only_root_owned_copies_and_off_restores_bashrc() {
  t_ubuntu_bashrc
  ss install core --yes >/dev/null 2>&1 || t_fail "install failed"
  # like a release install: ~/.local/bin/starship -> a file inside the user's home.
  # (`starship init` names the path it was CALLED by — the link, not its target.)
  local opt="$HOME/.local/share/supershell/opt/starship/1.27.0"
  mkdir -p "$opt" "$HOME/.local/bin"; mv "$T_FAKE_BIN/starship" "$opt/starship"
  ln -s "$opt/starship" "$HOME/.local/bin/starship"
  cp "$SUPERSHELL_ROOT_HOME/.bashrc" "$T_TMP/root-bashrc.orig"
  local out; out="$(ss root on 2>&1)" || t_fail "root on failed: $out"
  assert_eq "$(grep -c 'supershell root prompt >>>' "$SUPERSHELL_ROOT_HOME/.bashrc")" 1
  ss root on >/dev/null 2>&1                                 # idempotent
  assert_eq "$(grep -c 'supershell root prompt >>>' "$SUPERSHELL_ROOT_HOME/.bashrc")" 1
  # the security rule: nothing root reads lives in (or points into) the user's home
  local f
  for f in "$SUPERSHELL_ROOT_ETC"/* "$SUPERSHELL_ROOT_HOME/.bashrc"; do
    if grep -q -- "$HOME" "$f"; then t_fail "root reads the user's home via ${f##*/}"; fi
  done
  assert_file "$SUPERSHELL_ROOT_LIB/starship"                # user-owned starship → copied
  grep -q -- "$SUPERSHELL_ROOT_LIB/starship" "$SUPERSHELL_ROOT_ETC/starship-init.bash" || t_fail "init does not use root's starship copy"
  # root gets supershell-theme with the root palette (the default)
  cmp -s "$HOME/.config/supershell/starship-supershell-theme-root.toml" "$SUPERSHELL_ROOT_ETC/starship.toml" || t_fail "root does not get the theme's root version"
  grep -q '^palette = "supershell-root"$' "$SUPERSHELL_ROOT_ETC/starship.toml" || t_fail "root palette"
  # a root shell: prompt from the root-owned config, nothing else of supershell
  T_OUT="$(HOME="$SUPERSHELL_ROOT_HOME" bash -ic 'echo "$STARSHIP_CONFIG|$(type -t ll || echo no-ll)"' </dev/null 2>/dev/null)"
  assert_eq "$T_OUT" "$SUPERSHELL_ROOT_ETC/starship.toml|no-ll"
  T_OUT="$(HOME="$SUPERSHELL_ROOT_HOME" SSH_CONNECTION="1 2 3 4" bash -ic 'echo "$STARSHIP_CONFIG"' </dev/null 2>/dev/null)"
  assert_eq "$T_OUT" "$SUPERSHELL_ROOT_ETC/starship-plain.toml"
  # doctor notices when root's copy falls behind the user's prompt
  assert_contains "$(ss doctor 2>&1)" "root prompt: on, same as yours"
  ss prompt tokyo-night >/dev/null 2>&1                     # root follows on its own
  assert_contains "$(ss doctor 2>&1)" "root prompt: on, same as yours"
  echo "# changed elsewhere" >>"$SUPERSHELL_ROOT_ETC/starship.toml"   # out of date some other way
  assert_contains "$(ss doctor 2>&1)" "root prompt is older than your current prompt"
  # off: /root/.bashrc back byte-for-byte, root-owned files gone
  ss root off >/dev/null 2>&1 || t_fail "root off failed"
  assert_same_file "$SUPERSHELL_ROOT_HOME/.bashrc" "$T_TMP/root-bashrc.orig"
  assert_no_file "$SUPERSHELL_ROOT_ETC"
  assert_no_file "$SUPERSHELL_ROOT_LIB/starship"
}

test_root_prompt_refuses_custom_modules_and_uninstall_removes_it() {
  ss install core --yes >/dev/null 2>&1 || t_fail "install failed"
  # [custom] modules run commands: never copied into a root shell
  printf '[custom.hello]\ncommand = "echo hi"\nwhen = true\n' >"$HOME/.config/supershell/prompt.toml"
  ss prompt apply >/dev/null 2>&1
  local out; out="$(ss root on 2>&1)" && t_fail "root on must refuse [custom]"
  assert_contains "$out" "[custom] modules"
  assert_no_file "$SUPERSHELL_ROOT_ETC/init.bash"
  if grep -q 'supershell root prompt' "$SUPERSHELL_ROOT_HOME/.bashrc"; then t_fail "block added anyway"; fi
  rm -f "$HOME/.config/supershell/prompt.toml"; ss prompt apply >/dev/null 2>&1
  ss root on >/dev/null 2>&1 || t_fail "root on failed"
  ss uninstall --yes >/dev/null 2>&1
  if grep -q 'supershell root prompt' "$SUPERSHELL_ROOT_HOME/.bashrc"; then t_fail "uninstall left the root block"; fi
  assert_no_file "$SUPERSHELL_ROOT_ETC"
}

test_root_prompt_follows_theme_changes() {
  # Found on the laptop: root kept an old copy after the theme / root colours changed.
  ss install core --yes >/dev/null 2>&1 || t_fail "install failed"
  ss root on >/dev/null 2>&1 || t_fail "root on failed"
  local rc="$SUPERSHELL_ROOT_ETC/starship.toml"
  grep -q '^palette = "supershell-root"$' "$rc" || t_fail "root starts with the root palette"
  ss theme root-colors nord >/dev/null 2>&1 || t_fail "root-colors failed"
  grep -q '^palette = "nord"$' "$rc" || t_fail "root copy not updated by theme root-colors"
  ss theme root-colors same >/dev/null 2>&1; ss theme colors dracula >/dev/null 2>&1
  grep -q '^palette = "dracula"$' "$rc" || t_fail "root copy not updated by theme colors (root = same)"
  ss config set theme_root_colors supershell-root >/dev/null 2>&1
  grep -q '^palette = "supershell-root"$' "$rc" || t_fail "root copy not updated by config set"
  ss theme reset --yes >/dev/null 2>&1
  cmp -s "$HOME/.config/supershell/starship-supershell-theme-root.toml" "$rc" || t_fail "root copy not updated by reset"
  assert_contains "$(ss doctor 2>&1)" "root prompt: on, same as yours"
  # root off: nothing follows any more, and nothing asks for sudo
  ss root off >/dev/null 2>&1; : >"$T_APT/log"
  ss theme colors nord >/dev/null 2>&1
  if grep -q '^sudo' "$T_APT/log"; then t_fail "sudo used while the root prompt is off"; fi
  assert_no_file "$rc"
}

test_font_size_is_fitted_so_the_bar_glyphs_fill_the_line() {
  # VTE rounds the line height; at some sizes the bar's rounded ends end a pixel short.
  T_FONTFIT_TO=14.75 ss install core fonts --yes >/dev/null 2>&1 || t_fail "install failed"
  assert_contains "$(cat "$T_TMP/gsettings")" "font-name='Cascadia Code NF 14.75'"
  assert_eq "$(ss config get font_size)" 14                          # what you asked for is kept
  T_FONTFIT_TO=14.75 ss font jetbrains-mono >/dev/null 2>&1
  assert_contains "$(cat "$T_TMP/gsettings")" "font-name='JetBrains Mono 14.75'"
  # the screen changes: doctor says so; applying the size again re-fits
  assert_contains "$(T_FONTFIT_TO=15.25 ss doctor 2>&1)" "the screen changed: JetBrains Mono 15.25 fits"
  T_FONTFIT_TO=15.25 ss config set font_size 14 >/dev/null 2>&1
  assert_contains "$(cat "$T_TMP/gsettings")" "font-name='JetBrains Mono 15.25'"
  # off: exactly the size asked for
  ss config set font_fit off >/dev/null 2>&1
  assert_contains "$(cat "$T_TMP/gsettings")" "font-name='JetBrains Mono 14'"
}

test_real_fontfit_picks_a_size_that_fits() {
  # the real calculation (VTE's formula through Pango), when this machine can run it
  python3 -I -c 'import gi; gi.require_version("PangoCairo", "1.0")' 2>/dev/null || t_skip "PyGObject/Pango not available"
  fc-list 2>/dev/null | grep -q "Cascadia Code NF" || [[ -n "$(command -v /usr/bin/fc-list)" && -n "$(/usr/bin/fc-list "Cascadia Code NF")" ]] \
    || t_skip "Cascadia Code NF not installed on this machine"
  local s dpi got
  for dpi in 96 120 144 192; do   # text scaling 1, 1.25, 1.5, 2
    for s in 11 12 13 14 15 16; do
      got="$(python3 -I "$T_REPO/lib/fontfit.py" "Cascadia Code NF" "$s" "$dpi")"
      [[ "$got" =~ ^[0-9]+(\.[0-9]+)?$ ]] || t_fail "not a size: $got"
      awk -v g="$got" -v s="$s" 'BEGIN { exit !(g >= s - 1 && g <= s + 1.5) }' || t_fail "$s at $dpi dpi → $got (too far)"
    done
  done
  # the laptop case that showed the step (1.25 display scale, text scale 1 → 96 dpi):
  # 14 and 14.75 end a pixel short, 14.5 fills the line
  assert_eq "$(python3 -I "$T_REPO/lib/fontfit.py" "Cascadia Code NF" 14 96)" "14.5"
}

test_ends_font_matches_its_generator() {
  # config/fonts/SupershellEnds.ttf is generated (scripts/gen-ends-font.py); the bytes
  # are reproducible, so a fresh run must give the same file
  python3 -I -c 'import fontTools' 2>/dev/null || t_skip "fontTools not available (apt install python3-fonttools)"
  python3 -I "$T_REPO/scripts/gen-ends-font.py" "$T_TMP/ends.ttf" >/dev/null 2>&1 || t_fail "generator failed"
  cmp -s "$T_TMP/ends.ttf" "$T_REPO/config/fonts/SupershellEnds.ttf" || t_fail "SupershellEnds.ttf is not what scripts/gen-ends-font.py makes — run it"
}
