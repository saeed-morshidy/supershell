# shellcheck shell=bash
# How the installed environment behaves inside real Bash processes.

_install() { (($#)) || set -- core git devops; ss install "$@" --yes >/dev/null 2>&1 || t_fail "install failed"; }

test_interactive_startup_is_silent() {
  t_ubuntu_bashrc; _install core git editor fonts devops
  t_ibash 'true'
  assert_eq "$T_OUT" "" "stdout at start-up"
  assert_eq "$T_ERR" "" "stderr at start-up"
}

test_non_interactive_shells_are_untouched() {
  t_ubuntu_bashrc; _install
  local out
  out="$(bash -c 'alias; echo "loaded=${__SS_LOADED:-no} fzf=${SS_STUB_FZF:-no}"')"
  assert_eq "$out" "loaded=no fzf=no"
  printf '#!/bin/bash\nset -eu\nls / >/dev/null\necho "script ok: $(type -t ll || echo none)"\n' >"$T_TMP/s.sh"
  assert_eq "$(bash "$T_TMP/s.sh")" "script ok: none"
}

test_standard_commands_are_never_redefined() {
  t_ubuntu_bashrc; _install core git editor devops
  local cmds='for c in ls cat grep find cd vi vim less cp mv rm git man; do printf "%s=%s;" "$c" "$(type -t "$c")"; done'
  t_ibash "SUPERSHELL_DISABLE=1; $cmds"; local plain="$T_OUT"
  t_ibash "$cmds"
  assert_eq "$T_OUT" "$plain"
  t_ibash "$cmds; SUPERSHELL_DISABLE=1 bash -ic '$cmds' 2>/dev/null"
}

test_user_aliases_functions_and_variables_survive() {
  t_ubuntu_bashrc; echo "alias ll='ls -lh --my-style'" >>"$HOME/.bashrc"; _install
  t_ibash 'alias gs; mytool; echo "$MY_VAR"; alias ll'
  assert_contains "$T_OUT" "alias gs='git status'"
  assert_contains "$T_OUT" "user function works"
  assert_contains "$T_OUT" "hello"
  assert_contains "$T_OUT" "ls -lh --my-style" "a customised ll must be kept"
}

test_new_tools_get_new_names() {
  t_ubuntu_bashrc; _install
  t_ibash 'alias ll; alias lt; type -t z; echo "$PS1"'
  assert_contains "$T_OUT" "eza -l --git"
  assert_contains "$T_OUT" "eza --tree"
  assert_contains "$T_OUT" "function"
  assert_contains "$T_OUT" "[ss-prompt]"
}

test_classic_mode_is_plain_bash() {
  t_ubuntu_bashrc; _install
  ss mode classic >/dev/null 2>&1
  t_ibash 'echo "ps1=$PS1"; type -t z || echo noz; alias ll'
  assert_not_contains "$T_OUT" "ss-prompt"
  assert_contains "$T_OUT" "noz"
  assert_contains "$T_OUT" "alias ll='ls -alF'"
  ss mode modern >/dev/null 2>&1
  t_ibash 'echo "$PS1"'; assert_contains "$T_OUT" "ss-prompt"
}

test_disable_variable_skips_everything() {
  t_ubuntu_bashrc; _install
  t_ibash 'echo "${__SS_LOADED:-off}"' ; assert_eq "$T_OUT" 1
  T_OUT="$(SUPERSHELL_DISABLE=1 bash -ic 'echo "${__SS_LOADED:-off}"' </dev/null 2>/dev/null)"
  assert_eq "$T_OUT" off
}

test_init_is_cached_no_tool_runs_on_second_start() {
  t_ubuntu_bashrc; _install
  t_ibash true
  : >"$T_TMP/calls"
  t_ibash true
  assert_eq "$(cat "$T_TMP/calls")" "" "tools were executed during a cached start-up"
}

test_init_cache_is_rebuilt_when_the_binary_changes() {
  # e.g. starship moving from apt (/usr/bin) to the pinned release (~/.local/bin):
  # the release keeps an OLD file date, so only the recorded path can tell.
  t_ubuntu_bashrc; _install
  t_ibash true
  assert_contains "$(head -1 "$HOME/.cache/supershell/init/starship.bash")" "bin=$T_FAKE_BIN/starship"
  mkdir -p "$HOME/.local/bin"; cp "$T_FAKE_BIN/starship" "$HOME/.local/bin/starship"
  touch -d '2020-01-01' "$HOME/.local/bin/starship"
  : >"$T_TMP/calls"
  t_ibash true
  assert_contains "$(cat "$T_TMP/calls")" "starship init bash"
  assert_contains "$(head -1 "$HOME/.cache/supershell/init/starship.bash")" "bin=$HOME/.local/bin/starship"
  : >"$T_TMP/calls"; t_ibash true
  assert_eq "$(cat "$T_TMP/calls")" "" "cache must be reused once rebuilt"
}

test_sourcing_bashrc_twice_does_not_duplicate() {
  t_ubuntu_bashrc; _install
  t_ibash 'source ~/.bashrc; source ~/.bashrc; tr ":" "\n" <<<"$PATH" | grep -c "/.local/bin$"'
  assert_eq "$T_OUT" 1
}

test_devops_completions_are_lazy_files_and_respect_user_files() {
  t_ubuntu_bashrc
  cp "$T_REPO/tests/stubs/fake-tool" "$T_FAKE_BIN/kubectl"
  local cdir="$HOME/.local/share/bash-completion/completions"
  mkdir -p "$cdir"; echo "# my gh completion" >"$cdir/gh"
  cp "$T_REPO/tests/stubs/fake-tool" "$T_FAKE_BIN/gh"
  _install
  assert_contains "$(cat "$cdir/kubectl")" "managed by supershell"
  assert_eq "$(cat "$cdir/gh")" "# my gh completion"
  assert_no_file "$cdir/helm"
  # unchanged completions are not rewritten or announced on every setting change
  local out; out="$(ss config set icons auto 2>&1)"
  assert_not_contains "$out" "completion:"
  assert_contains "$(cat "$cdir/kubectl")" "managed by supershell"
  # a tool that is gone loses its completion file
  rm -f "$T_FAKE_BIN/kubectl"; ss config set icons auto >/dev/null 2>&1
  assert_no_file "$cdir/kubectl"
  cp "$T_REPO/tests/stubs/fake-tool" "$T_FAKE_BIN/kubectl"; ss config set icons auto >/dev/null 2>&1
  ss devops off >/dev/null 2>&1
  assert_no_file "$cdir/kubectl"
  assert_eq "$(cat "$cdir/gh")" "# my gh completion"
}

test_devops_aliases_are_opt_in() {
  t_ubuntu_bashrc; cp "$T_REPO/tests/stubs/fake-tool" "$T_FAKE_BIN/kubectl"; _install
  t_ibash 'type -t k || echo none'; assert_eq "$T_OUT" none
  ss devops aliases on >/dev/null 2>&1
  t_ibash 'alias k'; assert_contains "$T_OUT" "kubectl"
  assert_file "$HOME/.local/share/bash-completion/completions/k"
}

test_devops_prompt_toggle_renders_config() {
  _install
  grep -A1 '^\[kubernetes\]' -m1 "$HOME/.config/supershell/starship-plain.toml" >/dev/null
  assert_contains "$(grep -A3 '^\[kubernetes\]' "$HOME/.config/supershell/starship-plain.toml")" "disabled = false"
  ss devops off >/dev/null 2>&1
  assert_contains "$(grep -A3 '^\[kubernetes\]' "$HOME/.config/supershell/starship-plain.toml")" "disabled = true"
}

test_icons_follow_font_and_ssh() {
  t_ubuntu_bashrc; _install core fonts
  t_ibash 'echo "$SUPERSHELL_ICONS $STARSHIP_CONFIG"'
  assert_contains "$T_OUT" "nerd"; assert_contains "$T_OUT" "starship-pastel-powerline.toml"   # default style, Nerd icons
  T_OUT="$(SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" bash -ic 'echo "$SUPERSHELL_ICONS"' </dev/null 2>/dev/null)"
  assert_eq "$T_OUT" plain
  ss icons plain >/dev/null 2>&1
  t_ibash 'echo "$SUPERSHELL_ICONS"'; assert_eq "$T_OUT" plain
}

test_plain_prompt_config_has_no_private_use_glyphs() {
  _install core
  if LC_ALL=C.UTF-8 grep -P '[\x{E000}-\x{F8FF}\x{F0000}-\x{FFFFD}]' "$HOME/.config/supershell/starship-plain.toml"; then
    t_fail "plain prompt contains Nerd Font glyphs"
  fi
  # nerd prompt: the branch icon comes from starship's nerd-font-symbols preset (Private Use Area)
  awk '/^\[/{s=$0} s=="[git_branch]" && /^symbol/' "$HOME/.config/supershell/starship-nerd.toml" | LC_ALL=C.UTF-8 grep -qP '[\x{E000}-\x{F8FF}]' \
    || t_fail "nerd prompt lacks a Nerd Font branch glyph"
}

test_editor_env_respects_user_choices() {
  t_ubuntu_bashrc; _install core editor
  t_ibash 'echo "$EDITOR|$NVIM_APPNAME"'; assert_eq "$T_OUT" "nvim|supershell-nvim"
  echo 'export EDITOR=vim' >"$T_TMP/pre"; sed -i "1r $T_TMP/pre" "$HOME/.bashrc"
  mkdir -p "$HOME/.config/nvim"
  t_ibash 'echo "$EDITOR|${NVIM_APPNAME:-none}"; type -t snvim'
  assert_contains "$T_OUT" "vim|none"
  assert_contains "$T_OUT" "function"
}

test_git_pager_falls_back_when_delta_is_missing() {
  _install core git
  local pager; pager="$(git config --global --includes --get core.pager)"
  assert_contains "$pager" "delta"
  # A PATH with no delta at all (the real one may exist in /usr/bin on the host).
  mkdir -p "$T_TMP/minbin"
  local b; for b in sh less cat; do ln -sf "$(command -v "$b")" "$T_TMP/minbin/$b"; done
  assert_eq "$(printf 'diff text\n' | PATH="$T_TMP/minbin" sh -c "$pager")" "diff text"
}

test_ssh_style_non_tty_commands_get_clean_output() {
  # scp/rsync/ssh host cmd run a non-interactive shell; output must be byte-exact.
  t_ubuntu_bashrc; _install
  assert_eq "$(bash -c 'printf "%s" data')" "data"
}

test_preset_prompts_default_and_fall_back_without_nerd_icons() {
  t_ubuntu_bashrc; _install core fonts devops
  local g="$HOME/.config/supershell/starship-gruvbox-rainbow.toml"
  assert_file "$g"
  assert_file "$HOME/.config/supershell/starship-tokyo-night.toml"
  t_ibash 'echo "$STARSHIP_CONFIG"'; assert_contains "$T_OUT" "starship-pastel-powerline.toml"   # default
  # pastel-powerline is a one-line preset: supershell adds the line break (always two lines)
  local pp="$HOME/.config/supershell/starship-pastel-powerline.toml"
  grep -q '^\$fill\\$' "$pp" || t_fail "pastel-powerline: supershell's settings are not the default"
  ss prompt custom off >/dev/null 2>&1 || t_fail "prompt custom off failed"
  LC_ALL=C.UTF-8 grep -qP '^\[\x{E0B6}\]\((fg:)?#9A348E\)\\$' "$pp" || t_fail "custom off: not the preset as published (no rounded start)"
  grep -q '^\$kubernetes\$cmd_duration\$jobs\$status\\n\$character"""$' "$pp" || t_fail "custom off: no second line / extras"
  ss prompt custom on >/dev/null 2>&1
  grep -q '^\$kubernetes\$cmd_duration\$jobs\$status\\n\$character"""$' "$HOME/.config/supershell/starship-tokyo-night.toml" || t_fail "extras not in tokyo-night format"
  ss config set prompt_style gruvbox-rainbow >/dev/null 2>&1 || t_fail "config set failed"
  t_ibash 'echo "$STARSHIP_CONFIG"'; assert_contains "$T_OUT" "starship-gruvbox-rainbow.toml"
  # over SSH the icons are plain, so the segmented style must not be used
  T_OUT="$(SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" bash -ic 'echo "$STARSHIP_CONFIG"' </dev/null 2>/dev/null)"
  assert_contains "$T_OUT" "starship-plain.toml"
  ss config set prompt_style simple >/dev/null 2>&1 || t_fail "config set failed"
  t_ibash 'echo "$STARSHIP_CONFIG"'; assert_contains "$T_OUT" "starship-nerd.toml"
  # the preset is used as published: its palette and segment colours are untouched
  grep -q "^palette = 'gruvbox_dark'" "$g" || t_fail "preset palette missing"
  assert_contains "$(grep -A3 '^\[directory\]' "$g")" 'style = "fg:color_fg0 bg:color_yellow"'
  # supershell's extras were added: modules in the format, k8s on (devops), counts
  grep -q '^\$kubernetes\$cmd_duration\$jobs\$status\$line_break\$character"""$' "$g" || t_fail "extras not in format"
  assert_contains "$(grep -A3 '^\[kubernetes\]' "$g")" "disabled = false"
  assert_contains "$(grep -A12 '^\[git_status\]' "$g")" 'modified = "!${count}"'
  if grep -q '@[A-Z_]*@' "$g"; then t_fail "unrendered placeholder"; fi
  # catppuccin: one file per flavour, each selecting its own palette from the preset;
  # the preset already shows the command duration, so it must not be added twice;
  # always two lines (the preset turns the line break off)
  local fl c
  for fl in mocha macchiato frappe latte; do
    c="$HOME/.config/supershell/starship-catppuccin-$fl.toml"
    assert_file "$c"
    grep -q "^palette = 'catppuccin_$fl'$" "$c" || t_fail "catppuccin-$fl: wrong palette"
    assert_eq "$(grep -o '\$cmd_duration' "$c" | wc -l)" 1 "catppuccin-$fl: cmd_duration count"
    grep -q '^\$kubernetes\$jobs\$status\$line_break' "$c" || t_fail "catppuccin-$fl: extras missing"
    assert_contains "$(grep -A1 '^\[line_break\]' "$c")" "disabled = false"
  done
  ss config set prompt_style catppuccin-latte >/dev/null 2>&1 || t_fail "config set failed"
  t_ibash 'echo "$STARSHIP_CONFIG"'; assert_contains "$T_OUT" "starship-catppuccin-latte.toml"
}

test_toml_merge_adds_keys_and_never_changes_base_values() {
  cat >"$T_TMP/base.toml" <<'T'
format = """
$a\
$line_break"""

[x]
style = "base"
format = '[x]'

[y.z]
k = 1
T
  cat >"$T_TMP/over.toml" <<'T'
# comment dropped
format = "overlay must not win"
[x]
style = "overlay must not win"
added = "yes"
multi = """
two
lines"""
[new]
n = 2
T
  local out; out="$(awk -f "$T_REPO/lib/toml-merge.awk" "$T_TMP/over.toml" "$T_TMP/base.toml")"
  assert_not_contains "$out" "overlay must not win"
  assert_not_contains "$out" "comment dropped"
  assert_contains "$out" $'format = """\n$a\\\n$line_break"""'
  assert_contains "$out" $'style = "base"\nformat = \'[x]\'\nadded = "yes"\nmulti = """\ntwo\nlines"""'
  assert_contains "$out" $'[y.z]\nk = 1'
  assert_contains "$out" $'[new]\nn = 2'
  # quoted keys are keys too (the presets use "$schema" and "Documents")
  printf '"$schema" = "s"\n[d.subs]\n"My Docs" = "x"\n' >"$T_TMP/over2.toml"; printf '[d.subs]\n"My Docs" = "base"\n' >"$T_TMP/base2.toml"
  out="$(awk -f "$T_REPO/lib/toml-merge.awk" "$T_TMP/over2.toml" "$T_TMP/base2.toml")"
  assert_contains "$out" '"$schema" = "s"'
  assert_eq "$(grep -c 'My Docs' <<<"$out")" 1 "quoted key duplicated"
  command -v python3 >/dev/null && { python3 -I -c 'import sys,tomllib; tomllib.loads(sys.stdin.read())' <<<"$out" || t_fail "merged file is not valid TOML"; }
  return 0
}

test_real_starship_renders_prompt_without_warnings() {
  # Catches upstream preset changes: uses the real starship when this machine has one.
  [[ -n "$T_REAL_STARSHIP" ]] || t_skip "starship is not installed on this machine"
  _install core fonts devops
  ln -sf "$T_REAL_STARSHIP" "$T_FAKE_BIN/starship"
  ss config set devops on >/dev/null 2>&1 || t_fail "re-render failed"   # re-renders with the real presets
  local f out
  mkdir -p "$T_TMP/r/مشروع" && cd "$T_TMP/r/مشروع"
  _check() {   # own STARSHIP_CACHE per check: starship shows a warning once per session
    local c="$T_TMP/sc.$RANDOM$RANDOM"
    assert_file "$HOME/.config/supershell/starship-$1.toml"
    out="$(STARSHIP_CACHE="$c" STARSHIP_CONFIG="$HOME/.config/supershell/starship-$1.toml" STARSHIP_LOG=warn starship prompt 2>&1 >/dev/null)"
    assert_eq "$out" "" "starship warnings for $1 ($2)"
    out="$(STARSHIP_CACHE="$c" STARSHIP_CONFIG="$HOME/.config/supershell/starship-$1.toml" starship prompt 2>/dev/null)"
    assert_contains "$out" "مشروع"
  }
  for f in pastel-powerline tokyo-night gruvbox-rainbow catppuccin-mocha catppuccin-latte nerd plain; do
    _check "$f" default
  done
  # the preset as published, and supershell's settings with the rounded start
  ss prompt custom off >/dev/null 2>&1 || t_fail "prompt custom off failed"
  _check pastel-powerline "starship preset as published"
  ss prompt custom on >/dev/null 2>&1 || t_fail "prompt custom on failed"
  ss prompt cap on >/dev/null 2>&1 || t_fail "prompt cap on failed"
  _check pastel-powerline "custom, cap"
}

test_rendered_prompt_configs_are_valid_toml() {
  command -v python3 >/dev/null || t_skip "python3 not available"
  _install core
  local f
  for f in "$HOME"/.config/supershell/starship-{nerd,plain,pastel-powerline,gruvbox-rainbow,tokyo-night,catppuccin-mocha,catppuccin-macchiato,catppuccin-frappe,catppuccin-latte}.toml; do
    python3 -I -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$f" 2>&1 || t_fail "invalid TOML: $f"
  done
}

test_user_prompt_changes_win_and_apply_to_every_style() {
  t_ubuntu_bashrc; _install core fonts
  cat >"$HOME/.config/supershell/prompt.toml" <<'T'
# my tweaks
[time]
disabled = true

[directory]
truncation_length = 2
T
  local out f; out="$(ss prompt apply 2>&1)" || t_fail "prompt apply failed: $out"
  assert_contains "$out" "applied"
  for f in tokyo-night catppuccin-mocha nerd plain; do
    f="$HOME/.config/supershell/starship-$f.toml"
    assert_contains "$(awk '/^\[/{s=$0} s=="[time]"' "$f")" "disabled = true"
    assert_contains "$(awk '/^\[/{s=$0} s=="[directory]"' "$f")" "truncation_length = 2"
  done
  f="$HOME/.config/supershell/starship-tokyo-night.toml"
  # the preset's own values for other keys are kept, and it is still one valid file
  assert_contains "$(awk '/^\[/{s=$0} s=="[directory]"' "$f")" 'style = "fg:#e3e5e5 bg:#769ff0"'
  assert_eq "$(grep -c '^\[directory\]$' "$f")" 1 "duplicate [directory] table"
  assert_eq "$(grep -c '^format = """' "$f")" 1 "duplicate top-level format"
  if command -v python3 >/dev/null; then
    python3 -I -c 'import sys,tomllib; tomllib.load(open(sys.argv[1],"rb"))' "$f" || t_fail "invalid TOML after merge"
  fi
  # survives switching style and re-rendering; never written by supershell
  ss prompt gruvbox-rainbow >/dev/null 2>&1 || t_fail "prompt <style> failed"
  assert_contains "$(awk '/^\[/{s=$0} s=="[time]"' "$HOME/.config/supershell/starship-gruvbox-rainbow.toml")" "disabled = true"
  assert_eq "$(head -1 "$HOME/.config/supershell/prompt.toml")" "# my tweaks"
  out="$(ss doctor 2>&1)"; assert_contains "$out" "your prompt changes are applied"
  # uninstall keeps a copy in the backups
  out="$(ss uninstall --yes 2>&1)"; assert_contains "$out" "prompt.toml was saved in the backups"
  [[ -n "$(find "$HOME/.local/state/supershell/backups" -name prompt.toml)" ]] || t_fail "prompt.toml not backed up"
}

test_broken_user_prompt_is_ignored_with_a_clear_message() {
  [[ -n "$T_REAL_STARSHIP" ]] || t_skip "starship is not installed on this machine (needed to validate)"
  _install core fonts
  ln -sf "$T_REAL_STARSHIP" "$T_FAKE_BIN/starship"
  ss prompt apply >/dev/null 2>&1
  cp "$HOME/.config/supershell/starship-tokyo-night.toml" "$T_TMP/before"
  printf '[directory]\ntruncation_length = "two"\n' >"$HOME/.config/supershell/prompt.toml"
  local out; out="$(ss prompt apply 2>&1)"
  assert_contains "$out" "was NOT applied"
  assert_contains "$out" "truncation_length"
  assert_same_file "$HOME/.config/supershell/starship-tokyo-night.toml" "$T_TMP/before"
  out="$(ss doctor 2>&1)"; assert_contains "$out" "is ignored"
  # fixed file: applied, message gone
  printf '[directory]\ntruncation_length = 2\n' >"$HOME/.config/supershell/prompt.toml"
  out="$(ss prompt apply 2>&1)"; assert_contains "$out" "applied"
  assert_no_file "$HOME/.local/state/supershell/prompt-error"
}

test_supershell_prompt_is_default_full_width_square_and_your_file_still_wins() {
  t_ubuntu_bashrc; _install core fonts
  local pp="$HOME/.config/supershell/starship-pastel-powerline.toml" fmt
  assert_eq "$(ss prompt custom 2>&1)" "custom prompt settings: on"   # the default
  fmt="$(sed -n '/^format = """/,/"""$/p' "$pp")"
  # the preset's look: its 5 powerline arrows (real glyph U+E0B0) and colours
  assert_eq "$(LC_ALL=C.UTF-8 grep -oP '\x{E0B0}' <<<"$fmt" | wc -l)" 5 "arrows"
  LC_ALL=C.UTF-8 grep -qP '^\[\x{E0B0}\]\(fg:#06969A bg:#33658A\)\\$' <<<"$fmt" || t_fail "arrow into the last colour"
  # full width: the last colour fills to the right edge, clock at the right, square end
  grep -q '^\$fill\\$' <<<"$fmt" || t_fail "no \$fill"
  assert_contains "$(awk '/^\[/{s=$0} s=="[fill]"' "$pp")" 'style = "bg:#33658A"'
  assert_eq "$(grep -A1 '^\$fill\\$' <<<"$fmt" | tail -1)" '$time\' "clock right after the fill"
  assert_eq "$(grep -A1 '^\$time\\$' <<<"$fmt" | tail -1)" '$line_break\' "line must end square after the clock"
  # square start: the first thing is the OS/user block, no rounded cap
  assert_eq "$(sed -n 2p <<<"$fmt")" '$os\' "square start"
  if LC_ALL=C.UTF-8 grep -qP '[\x{E0B4}\x{E0B6}]' <<<"$fmt"; then t_fail "rounded glyph in the default"; fi
  # still two lines, extras in front of the prompt sign; rest of the preset kept
  grep -q '^\$kubernetes\$cmd_duration\$jobs\$status\$character"""$' "$pp" || t_fail "extras not on the second line"
  assert_contains "$(awk '/^\[/{s=$0} s=="[username]"' "$pp")" 'style_user = "bg:#9A348E"'
  assert_eq "$(grep -c '^format = """' "$pp")" 1 "duplicate format"
  # only styles with ready-made settings change
  if grep -q '\$fill' "$HOME/.config/supershell/starship-tokyo-night.toml"; then t_fail "tokyo-night changed"; fi
  # the preset's rounded start is an option
  ss prompt cap on >/dev/null 2>&1 || t_fail "prompt cap on failed"
  LC_ALL=C.UTF-8 grep -qP '^\[\x{E0B6}\]\((fg:)?#9A348E\)\\$' "$pp" || t_fail "cap not added with prompt cap on"
  grep -q '^\$fill\\$' "$pp" || t_fail "cap variant lost \$fill"
  ss prompt cap off >/dev/null 2>&1
  if LC_ALL=C.UTF-8 grep -qP '^\[\x{E0B6}\]\((fg:)?#9A348E\)\\$' "$pp"; then t_fail "cap still there after cap off"; fi
  # your own file still wins over supershell's settings
  printf '[fill]\nstyle = "bg:#000000"\n' >"$HOME/.config/supershell/prompt.toml"
  ss prompt apply >/dev/null 2>&1
  assert_contains "$(awk '/^\[/{s=$0} s=="[fill]"' "$pp")" 'style = "bg:#000000"'
  # off = the preset exactly as starship publishes it (plus two lines + extras)
  ss prompt custom off >/dev/null 2>&1
  if grep -q '^\$fill\\$' "$pp"; then t_fail "supershell settings still used after off"; fi
}

test_install_asks_which_prompt_once() {
  local out
  out="$(ss install core --default --dry-run 2>&1)"; assert_contains "$out" "prompt settings: starship preset as published"
  ss install core --yes >/dev/null 2>&1 || t_fail "install failed"
  assert_eq "$(ss config get prompt_custom)" on   # --yes / no terminal = supershell's (the default)
  ss uninstall --yes >/dev/null 2>&1
  ss install core --default --yes >/dev/null 2>&1 || t_fail "install --default failed"
  assert_eq "$(ss config get prompt_custom)" off
  # not asked again on a later install: the choice is kept
  ss install core --custom --yes >/dev/null 2>&1 || t_fail "reinstall failed"
  assert_eq "$(ss config get prompt_custom)" off
}

test_no_empty_separators_in_any_prompt_config() {
  # A separator glyph lost while editing leaves "[](…)": square edges, silently.
  _install core fonts
  ss prompt custom on >/dev/null 2>&1
  local f bad=""
  for f in "$T_REPO"/config/starship/*.toml "$T_REPO"/config/starship/custom/*.toml \
           "$HOME"/.config/supershell/starship-*.toml; do
    grep -q '\[\](' "$f" && bad+=" ${f##*/}"
  done
  [[ -z "$bad" ]] || t_fail "empty separator [](…) in:$bad"
}
