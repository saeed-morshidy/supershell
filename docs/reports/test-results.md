# Test results — v0.1.0

Summary of every check, where it ran, and its result. Nothing is reported as
passed unless it actually ran.

## Status overview

| Check | Where | Result |
|---|---|---|
| Automated suite: unit, integration, Arabic, performance | build environment (Ubuntu 24.04 container, bash 5.2, stubbed tools) | **74 passed, 0 failed, 1 skipped** |
| Automated suite on the real laptop (Ubuntu 26.04.1, bash 5.3, real apt tools) | maintainer's laptop | **71 passed, 0 failed, 5 skipped** (before the 3 new download tests; skips: tmux ×3, Neovim ×1, root guard ×1) |
| Automated suite after adding download tests | maintainer's laptop | **74 passed, 0 failed, 5 skipped** (tmux ×3, Neovim ×1, root guard ×1) |
| Automated suite at the first commit (starship 1.27.0, prompt styles, fonts, user prompt layer) | maintainer's laptop | **91 passed, 0 failed, 4 skipped** (tmux ×3, root guard ×1) |
| Automated suite after the first-CI fixes, with tmux + shellcheck installed | maintainer's laptop | **96 passed, 0 failed, 1 skipped** (root guard); shellcheck 0.11.0 clean on both CI commands |
| Automated suite with Neovim 0.12.6 installed | maintainer's laptop | **78 passed, 0 failed, 4 skipped** (tmux ×3, root guard ×1); the Neovim Arabic test now runs and passes |
| Real install of `editor` + `fonts`, `doctor` | maintainer's laptop | ✅ install OK (font from the cached file; Neovim re-downloaded, see bugs); doctor 32 passed, 2 warnings (not run inside Ptyxis; no language servers yet), 0 problems |
| Neovim profile on the laptop | maintainer's laptop | ✅ loads with empty `v:errmsg`; 5/5 plugins installed and active; `termbidi=true`; Arabic line with diacritics round-trips byte-for-byte after edits |
| `bash -n` syntax check, all scripts | build environment | ✅ pass |
| TOML/XML validity of shipped configs (rendered prompts, Helix, Atuin, fontconfig) | build environment | ✅ pass |
| ShellCheck | laptop (0.11.0) + CI `lint` | ✅ clean locally; CI: see the latest run |
| Suite in `ubuntu:24.04` and `ubuntu:26.04` containers | CI `tests` | ⏳ not executed yet (runs on first push) |
| Real install / doctor / Neovim profile / Arabic in Neovim / bench / uninstall | CI `e2e (ubuntu-26.04)` | ⏳ not executed yet |
| Neovim Lua profile loads without errors | CI `e2e` | ⏳ not executed (no Neovim here); code reviewed by hand |
| Arabic visual behaviour (A1–A23) | manual, Ubuntu 26.04 + Ptyxis | ⏳ not executed — needs a human with a screen |
| Real start-up time on the target laptop | manual, `supershell bench` | ⏳ not executed |
| SSH session behaviour | partly automated (icons fall back to plain); real SSH in manual plan A21 | ⏳ manual part not executed |

## Bugs found while adding the root prompt

- `starship init` writes into its script the `starship` it finds on **PATH**, not the binary that is running. Generating root's script with root's own copy therefore still produced `~/.local/bin/starship` (a user-changeable file) on the laptop; the final safety check refused it. Fixed: the script is printed in a clean environment whose PATH starts at root's copy, and every `starship` it runs must be exactly that copy. The fake starship now behaves the same way (PATH lookup), so the test reproduces the laptop failure with the old code. Also: a refused attempt now removes what it created.

## Bugs found by the first CI run (GitHub Actions, run 42533623944)

- **e2e:** the install runs before `~/.local/bin` is on PATH (fresh server, `su -c`, CI),
  so the CLI could not find the starship and nvim it had just installed there: no prompt
  configs were rendered and the editor plugins were silently skipped. Fixed: the CLI
  puts `~/.local/bin` on its own PATH (doctor still reports the user's PATH). Test:
  `test_installed_tools_are_found_when_local_bin_is_not_on_path`; e2e step
  "editor plugins installed during install".
- **e2e:** without plugins, `doctor` started nvim, which made vim.pack download them, and
  read its progress on stderr as a profile error. Fixed: no load check (a warning) until
  plugins are installed; only `v:errmsg` counts. Test: `test_doctor_never_downloads_editor_plugins`.
- **tests (ubuntu-24.04):** the mixed Arabic/English editing test used the Home key, whose
  escape code the 24.04 container's inputrc does not map (the Arabic cursor steps were
  correct). The test now uses readline's own `C-a`.
- **lint:** shellcheck had never run locally (not installed). Fixed the real warnings
  (`cd` without `|| exit`); SC2015/SC2016/SC2088 are disabled in `.shellcheckrc` with the
  reason for each (all cases reviewed).

## Bugs found on real hardware (first laptop run)

- A stalled download hung forever — fixed: speed-limit/max-time/retry flags, no retry on HTTP 404, clear error messages, and files pre-downloaded into `~/.cache/supershell/dl/` are reused (still verified).
- Editor plugin install on a slow GitHub connection: a silent 3-minute wait, and when the timeout cut a clone off, the half-cloned plugin stayed and `vim.pack` treated it as installed (broken for good); a rollback also left the downloaded plugins behind — fixed: unfinished clones are removed, the step says it may take minutes and never fails the install, and the plugin directory is journaled. Covered by `test_slow_plugin_download_leaves_no_half_cloned_plugins` and the later-module rollback test.
- `doctor` reported "Symbols Nerd Font not found" although it was installed: `fc-list | grep -q` under `pipefail` fails with SIGPIPE when the font list is large (any real desktop). Fixed in all four `| grep -q` checks; the `fc-list` stub now prints a realistic list. Test: `test_doctor_finds_icon_font_on_a_big_font_list`.
- An interrupted/rolled-back run deleted the user's pre-downloaded archive (it was removed right after extraction, before the run committed). Fixed: downloaded archives are deleted only on commit. Test: `test_predownloaded_file_survives_a_rollback_and_is_cleaned_after_success`.
- The Neovim Arabic test was always skipped on a laptop: the sandbox's PATH never included the Neovim supershell installs into `~/.local/bin`. Fixed: the harness records the real Neovim and plugins before sandboxing (the test copies them; it never writes to the real profile).
- `doctor` printed `git ` without a version — fixed.
- After starship moved from apt (1.22.1) to the pinned release (1.27.0), the prompt kept running the old binary: the cached init script embedded `/usr/bin/starship` and was only rebuilt when the binary was *newer* than the cache, but a release keeps its build date. Fixed: the cache records the binary path; installing a tool clears its cache. Test: `test_init_cache_is_rebuilt_when_the_binary_changes`.
- starship ≥ 1.27 refuses to overwrite a file with `starship preset -o`, so only the first preset was rendered and the rest silently fell back. Found by `test_real_starship_renders_prompt_without_warnings` (real binary); fixed by reading presets from stdout; the stub now behaves like 1.27.
- Validation of the user's `prompt.toml` accepted a broken file for every style after the first: starship prints a given warning only once per log session. Fixed: each check uses its own `STARSHIP_CACHE`. Test: `test_broken_user_prompt_is_ignored_with_a_clear_message` (real starship).
- Same family as the `fc-list` bug: `… | grep -v …` returning "no match" (the normal case) aborted `prompt apply` under `set -e`/`pipefail` — fixed.
- The TOML merge did not treat quoted keys with `$` or spaces (`"$schema"`, `"My Docs"`) as keys — fixed, with a test.
- `uninstall` deleted the whole config folder, which would include the user's `prompt.toml` — it is now copied to the backups first.
- `scripts/update-manifest.sh` had no curl timeouts (could hang) and printed `git diff` usage outside a repository — fixed.
- The `sudo` test stub did not handle `sudo -v` — fixed.
- The delta-fallback test depended on the host having no `/usr/bin/delta` — fixed.

## Bugs found by the suite and fixed during development

1. A failing sub-shell inherited the error trap and **rolled back the previous
   run's journal by itself** — fixed: only the main process, and only the run that
   created the journal, may roll back.
2. A run refusing to start because of an interrupted earlier run **consumed** that
   run's journal — fixed (same ownership rule); covered by the kill -9 test.
3. `local link="$SS_BIN/$name"` on the same line as `name=` produced an empty path
   — fixed; binary links for `bat`/`fd` now work.
4. Backups taken inside `$(…)` were split across directories, and `restore` could
   loop forever reading the index it was appending to — fixed.
5. Mistyped module names silently installed nothing — now an error.
6. Several functions returned non-zero because their last line was `[[ … ]] && …`,
   aborting `install`, `remove` and `mode modern` — fixed.
7. `uninstall` refused to remove supershell's own top-level cache directory — fixed.
8. `restore --list` depended on `column`, which minimal Ubuntu lacks — removed.

## Full automated run

| group | test | result |
|---|---|---|
| unit | test_apt_preferred_when_new_enough_else_release | ✅ pass |
| unit | test_backup_and_restore | ✅ pass |
| unit | test_bashrc_block_insert_is_idempotent_and_preserves_content | ✅ pass |
| unit | test_bashrc_detects_duplicate_tool_init | ✅ pass |
| unit | test_bashrc_missing_is_created_and_removed_cleanly | ✅ pass |
| unit | test_bashrc_remove_restores_byte_for_byte | ✅ pass |
| unit | test_bashrc_symlink_is_not_edited_without_consent | ✅ pass |
| unit | test_bashrc_without_final_newline_round_trips | ✅ pass |
| unit | test_config_set_validates | ✅ pass |
| unit | test_every_manifest_tool_has_both_architectures | ✅ pass |
| unit | test_install_refuses_unsupported_os_without_force | ✅ pass |
| unit | test_journal_blocks_new_run_until_repaired | ✅ pass |
| unit | test_journal_rollback_restores_and_removes | ✅ pass |
| unit | test_link_bin_never_clobbers_user_files | ✅ pass |
| unit | test_manifest_expands_version | ✅ pass |
| unit | test_os_2404_is_best_effort | ✅ pass |
| unit | test_os_aarch64_is_supported | ✅ pass |
| unit | test_os_debian_and_arm32_are_refused | ✅ pass |
| unit | test_os_detects_ubuntu_2604_as_primary | ✅ pass |
| unit | test_release_verified_by_upstream_sums_warns | ✅ pass |
| unit | test_release_with_pinned_checksum_installs | ✅ pass |
| unit | test_release_with_wrong_checksum_is_rejected_and_nothing_installed | ✅ pass |
| unit | test_release_without_any_checksum_is_refused | ✅ pass |
| unit | test_safe_rm_refuses_paths_outside_supershell | ✅ pass |
| unit | test_ubuntu_binary_names_get_friendly_links | ✅ pass |
| integration | test_dependencies_are_pulled_in | ✅ pass |
| integration | test_doctor_healthy_and_detects_problems | ✅ pass |
| integration | test_dry_run_changes_nothing | ✅ pass |
| integration | test_existing_user_pager_is_respected | ✅ pass |
| integration | test_failure_in_later_module_rolls_back_everything | ✅ pass |
| integration | test_fresh_install_defaults | ✅ pass |
| integration | test_install_selected_modules_only | ✅ pass |
| integration | test_interrupted_install_is_detected_and_repaired | ✅ pass |
| integration | test_missing_dependency_failure_rolls_back | ✅ pass |
| integration | test_offline_install_fails_cleanly | ✅ pass |
| integration | test_refuses_root_without_flag | ✅ pass |
| integration | test_reinstall_after_uninstall | ✅ pass |
| integration | test_repeated_install_is_idempotent | ✅ pass |
| integration | test_restore_brings_back_a_backup | ✅ pass |
| integration | test_uninstall_keeps_preexisting_apt_packages | ✅ pass |
| integration | test_uninstall_restores_bashrc_and_removes_everything | ✅ pass |
| integration | test_unknown_module_is_an_error | ✅ pass |
| integration | test_unverified_release_aborts_and_rolls_back | ✅ pass |
| integration | test_user_edited_config_is_never_overwritten_or_deleted | ✅ pass |
| integration | test_classic_mode_is_plain_bash | ✅ pass |
| integration | test_devops_aliases_are_opt_in | ✅ pass |
| integration | test_devops_completions_are_lazy_files_and_respect_user_files | ✅ pass |
| integration | test_devops_prompt_toggle_renders_config | ✅ pass |
| integration | test_disable_variable_skips_everything | ✅ pass |
| integration | test_editor_env_respects_user_choices | ✅ pass |
| integration | test_git_pager_falls_back_when_delta_is_missing | ✅ pass |
| integration | test_icons_follow_font_and_ssh | ✅ pass |
| integration | test_init_is_cached_no_tool_runs_on_second_start | ✅ pass |
| integration | test_interactive_startup_is_silent | ✅ pass |
| integration | test_new_tools_get_new_names | ✅ pass |
| integration | test_non_interactive_shells_are_untouched | ✅ pass |
| integration | test_plain_prompt_config_has_no_private_use_glyphs | ✅ pass |
| integration | test_sourcing_bashrc_twice_does_not_duplicate | ✅ pass |
| integration | test_ssh_style_non_tty_commands_get_clean_output | ✅ pass |
| integration | test_standard_commands_are_never_redefined | ✅ pass |
| integration | test_user_aliases_functions_and_variables_survive | ✅ pass |
| arabic | test_arabic_filenames_create_list_and_remove | ✅ pass |
| arabic | test_arabic_punctuation_and_diacritics_round_trip | ✅ pass |
| arabic | test_cursor_movement_and_editing_in_mixed_line | ✅ pass |
| arabic | test_doctor_flags_non_utf8_locale | ✅ pass |
| arabic | test_history_recall_of_arabic_commands | ✅ pass |
| arabic | test_neovim_keeps_arabic_text_intact | ⏭️ skipped — Neovim is not installed in this environment (runs in CI's Ubuntu 26.04 job) |
| arabic | test_plain_icon_set_uses_only_common_unicode | ✅ pass |
| arabic | test_prompt_in_arabic_directory_is_silent_and_correct | ✅ pass |
| arabic | test_search_arabic_content_with_ripgrep | ✅ pass |
| arabic | test_tab_completion_of_arabic_filenames | ✅ pass |
| perf | test_bench_command_runs | ✅ pass |
| perf | test_framework_overhead_is_small | ✅ pass |
| perf | test_memory_overhead_is_small | ✅ pass |
| perf | test_no_background_processes_after_startup | ✅ pass |

**74 passed, 0 failed, 1 skipped**
