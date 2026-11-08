# shellcheck shell=bash
# Backups, and a transaction journal so failed or interrupted runs roll back.

SS_JOURNAL="$SS_STATE/journal"
SS_BACKUP_SESSION=""

# Sets SS_BACKUP_SESSION once per run (call directly, not in $(...)).
_backup_session_init() {
  if [[ -z "$SS_BACKUP_SESSION" ]]; then
    SS_BACKUP_SESSION="$SS_STATE/backups/$(date +%Y%m%d-%H%M%S)-$$-$RANDOM"
  fi
  mkdir -p "$SS_BACKUP_SESSION"
}

# Copy a file into this run's backup set. Prints the backup path.
# Returns 1 (and prints nothing) if the file doesn't exist.
backup_file() {
  local src="$1" dir rel dest
  [[ -e "$src" || -L "$src" ]] || return 1
  _backup_session_init
  dir="$SS_BACKUP_SESSION"
  rel="${src#"$HOME"/}"; rel="${rel#/}"
  dest="$dir/files/$rel"
  mkdir -p "$(dirname "$dest")"
  cp -a -- "$src" "$dest"
  printf '%s\t%s\n' "$src" "$dest" >>"$dir/index.tsv"
  SS_BACKUP_LAST="$dest"
  printf '%s\n' "$dest"
}

backup_list() {
  local d
  for d in "$SS_STATE"/backups/*/; do
    [[ -f "$d/index.tsv" ]] || continue
    printf '%s\t%s\n' "$(basename "$d")" "$(cut -f1 "$d/index.tsv" | sed "s|^$HOME|~|" | sort -u | paste -sd, -)"
  done
}

# Restore every file of one backup set (current versions are backed up first).
backup_restore() {
  local id="$1" dir="$SS_STATE/backups/$1" orig copy entries=() e
  [[ -n "$id" && -f "$dir/index.tsv" ]] || die "No backup named '$id'. See: supershell restore --list"
  mapfile -t entries <"$dir/index.tsv"
  SS_BACKUP_SESSION=""   # current versions go into a new, separate backup set
  for e in "${entries[@]}"; do
    IFS=$'\t' read -r orig copy <<<"$e"
    [[ -e "$copy" || -L "$copy" ]] || { warn "missing backup copy for $orig"; continue; }
    if [[ -e "$orig" || -L "$orig" ]]; then backup_file "$orig" >/dev/null; fi
    mkdir -p "$(dirname "$orig")"
    rm -f -- "$orig"
    cp -a -- "$copy" "$orig"
    ok "restored ${orig/#$HOME/\~}"
  done
}

# ---- journal -----------------------------------------------------------------
journal_active() { [[ -f "$SS_JOURNAL" ]]; }
# True only for the process that started the current journal (never for a run that
# merely found a stale journal left by an interrupted run).
SS_JOURNAL_MINE=0
journal_mine() { [[ $SS_JOURNAL_MINE == 1 ]] && journal_active; }

journal_begin() {
  mkdir -p "$SS_STATE"
  if journal_active; then
    die "A previous supershell run did not finish (interrupted or crashed).
   Run 'supershell repair' to roll it back first."
  fi
  printf 'begin\t%s\t%s\n' "$(date +%s)" "$*" >"$SS_JOURNAL"
  SS_JOURNAL_MINE=1
}

journal_add() { journal_active || return 0; local IFS=$'\t'; printf '%s\n' "$*" >>"$SS_JOURNAL"; }

# `cleanup <file>` entries (e.g. a downloaded archive) are deleted only when the run
# succeeds; a rollback keeps them so the next attempt needs no new download.
journal_commit() {
  local type a b
  if [[ -f "$SS_JOURNAL" ]]; then
    while IFS=$'\t' read -r type a b; do
      [[ "$type" == cleanup ]] && rm -f -- "$a"
    done <"$SS_JOURNAL"
  fi
  rm -f -- "$SS_JOURNAL"; SS_JOURNAL_MINE=0
}

# Track a file we are about to create or modify.
journal_track_file() {
  local f="$1"
  if backup_file "$f" >/dev/null; then journal_add backup "$f" "$SS_BACKUP_LAST"
  else journal_add absent "$f"; fi
}

journal_rollback() {
  journal_active || return 0
  warn "Rolling back the unfinished changes…"
  local lines=() i type a b
  mapfile -t lines <"$SS_JOURNAL"
  for (( i=${#lines[@]}-1; i>=0; i-- )); do
    IFS=$'\t' read -r type a b <<<"${lines[i]}"
    case "$type" in
      backup)  rm -f -- "$a"; cp -a -- "$b" "$a" && detail "restored ${a/#$HOME/\~}" ;;
      absent)  if [[ -e "$a" || -L "$a" ]]; then rm -rf -- "$a"; detail "removed ${a/#$HOME/\~}"; fi ;;
      created) if ss_owned_path "$a"; then rm -rf -- "$a"; detail "removed ${a/#$HOME/\~}"; fi ;;
      module)  module_mark_removed "$a" ;;
      restore_app) if [[ -d "$a.old" ]]; then rm -rf -- "$a"; mv -- "$a.old" "$a"; detail "restored the previous supershell version"; fi ;;
      apt)     detail "apt package '$a' was installed and is kept (remove with: sudo apt remove $a)" ;;
      begin|cleanup) ;;   # cleanup: kept on rollback (see journal_commit)
    esac
  done
  rm -f -- "$SS_JOURNAL"; SS_JOURNAL_MINE=0
  ok "Rollback complete — your files are as they were before this run."
}
