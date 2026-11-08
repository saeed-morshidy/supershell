# shellcheck shell=bash
# Arabic / Unicode tests that can be automated.
#
# What these prove: Arabic text is stored, completed, searched and edited in the
# correct LOGICAL order inside a supershell session. What they cannot prove: how
# the terminal DRAWS it (right-to-left display, letter shaping, visual cursor).
# That depends on the terminal emulator and is covered by docs/arabic-test-plan.md.

_install() { ss install core devops --yes >/dev/null 2>&1 || t_fail "install failed"; }

# Start an interactive supershell bash inside tmux; tmux stores text in logical order.
_tmux_start() {
  command -v tmux >/dev/null || t_skip "tmux not installed"
  T_SOCK="ss-ar-$$"
  tmux -L "$T_SOCK" -f /dev/null -u new-session -d -x 160 -y 20 -c "$HOME" \
    "env -i HOME='$HOME' PATH='$PATH' LANG=C.UTF-8 LC_ALL=C.UTF-8 TERM=xterm-256color T_TMP='$T_TMP' bash -i"
  sleep 0.6
}
_tmux_keys() { tmux -L "$T_SOCK" send-keys "$@"; sleep 0.4; }
_tmux_screen() { tmux -L "$T_SOCK" capture-pane -p -J; }
_tmux_stop() { tmux -L "$T_SOCK" kill-server 2>/dev/null || true; }

test_arabic_filenames_create_list_and_remove() {
  _install
  t_ibash 'mkdir -p "مشاريع/تقارير 2026" && touch "مشاريع/تقارير 2026/ملخص-final.md" && ls "مشاريع/تقارير 2026"'
  assert_eq "$T_OUT" "ملخص-final.md"
  t_ibash 'rm -r "مشاريع" && echo gone'
  assert_eq "$T_OUT" gone
}

test_tab_completion_of_arabic_filenames() {
  _install; mkdir -p "$HOME/مستندات"; touch "$HOME/مستندات/تقرير_الربع_الأول.txt"
  _tmux_start
  _tmux_keys -l 'ls مستن'; _tmux_keys Tab; _tmux_keys -l 'تقر'; _tmux_keys Tab
  local screen; screen="$(_tmux_screen)"; _tmux_stop
  assert_contains "$screen" "ls مستندات/تقرير_الربع_الأول.txt"
}

test_cursor_movement_and_editing_in_mixed_line() {
  _install; _tmux_start
  # Type a mixed line, move the cursor over English and Arabic letters, insert, run.
  # Each Arabic letter must be exactly one cursor step (multibyte-safe editing).
  _tmux_keys -l 'echo "abc سلام xyz"'
  _tmux_keys Left Left Left Left Left Left      # " z y x space م
  _tmux_keys -l '*'
  _tmux_keys Home; _tmux_keys Right Right Right Right Right Right Right Right Right Right Right  # after: echo "abc س
  _tmux_keys -l '+'
  _tmux_keys Enter
  local screen; screen="$(_tmux_screen)"; _tmux_stop
  assert_contains "$screen" $'\nabc س+لا*م xyz'
  assert_not_contains "$screen" $'\ufffd' "broken UTF-8 after editing"
}

test_history_recall_of_arabic_commands() {
  _install; _tmux_start
  _tmux_keys -l 'echo "مرحبا بالعالم"'; _tmux_keys Enter
  _tmux_keys -l 'clear'; _tmux_keys Enter
  _tmux_keys Up Up; _tmux_keys Enter
  local screen; screen="$(_tmux_screen)"; _tmux_stop
  assert_contains "$screen" "مرحبا بالعالم"
}

test_arabic_punctuation_and_diacritics_round_trip() {
  _install
  local s='قالَ: «السلامُ عليكم»، كيف الحال؟ ١٢٣ — 123'
  printf '%s\n' "$s" >"$T_TMP/ar.txt"
  t_ibash "cat '$T_TMP/ar.txt'"
  assert_eq "$T_OUT" "$s"
}

test_search_arabic_content_with_ripgrep() {
  command -v rg >/dev/null || t_skip "ripgrep not installed here"
  [[ "$(command -v rg)" != "$T_FAKE_BIN"/* ]] || t_skip "only a stub rg is available"
  _install; mkdir -p "$HOME/notes"
  printf 'سطر أول\nكلمة البحث هنا\nEnglish line\n' >"$HOME/notes/ملاحظات.md"
  local out; out="$(cd "$HOME" && /usr/bin/rg -n 'البحث' notes)"
  assert_contains "$out" "notes/ملاحظات.md:2:كلمة البحث هنا"
}

test_prompt_in_arabic_directory_is_silent_and_correct() {
  _install; mkdir -p "$HOME/مجلد عربي"
  t_ibash 'cd "$HOME/مجلد عربي" && pwd'
  assert_eq "$T_OUT" "$HOME/مجلد عربي"; assert_eq "$T_ERR" ""
}

test_doctor_flags_non_utf8_locale() {
  _install
  local out; out="$(LANG=C LC_ALL=C LC_CTYPE=C ss doctor 2>&1)" || true
  assert_contains "$out" "Locale is not UTF-8"
}

test_plain_icon_set_uses_only_common_unicode() {
  _install
  # Every non-ASCII character in the plain prompt must be in DejaVu Sans Mono's
  # common blocks (arrows, dingbats, misc technical, · and ») — no Private Use Area.
  local chars; chars="$(LC_ALL=C.UTF-8 grep -oP '[^\x00-\x7F]' "$HOME/.config/supershell/starship-plain.toml" | sort -u | tr -d '\n')"
  assert_eq "$chars" "$(printf '%s' "$chars" | LC_ALL=C.UTF-8 grep -oP '[\x{2000}-\x{206F}\x{2190}-\x{27BF}\x{00B7}\x{00BB}]' | tr -d '\n')"
}

test_neovim_keeps_arabic_text_intact() {
  local nv="$T_REAL_NVIM" v
  [[ -n "$nv" ]] || t_skip "Neovim is not installed in this environment (runs in CI's Ubuntu 26.04 job)"
  v="$("$nv" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  [[ "${v%%.*}" -gt 0 || "${v#*.}" -ge 12 ]] || t_skip "Neovim $v is older than 0.12"
  _install
  ss install editor --yes >/dev/null 2>&1 || true
  # Reuse plugins already downloaded on this machine (a copy: the test never writes to
  # the real profile). Without them vim.pack clones from GitHub, as in CI.
  if [[ -d "$T_REAL_NVIM_PACK" ]]; then
    mkdir -p "$HOME/.local/share/supershell-nvim/site" && cp -r "$T_REAL_NVIM_PACK" "$HOME/.local/share/supershell-nvim/site/"
  fi
  printf 'سطر عربي mixed with English\n' >"$T_TMP/a.txt"
  NVIM_APPNAME=supershell-nvim timeout 60 "$nv" --headless "$T_TMP/a.txt" +'normal! A ✓' +wq >/dev/null 2>&1
  assert_eq "$(cat "$T_TMP/a.txt")" "سطر عربي mixed with English ✓"
  local tb; tb="$(NVIM_APPNAME=supershell-nvim timeout 60 "$nv" --headless +'lua io.stdout:write(tostring(vim.o.termbidi))' +qa 2>/dev/null)"
  assert_eq "$tb" true
}
