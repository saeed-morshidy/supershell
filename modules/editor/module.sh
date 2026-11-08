# shellcheck shell=bash
# editor — Neovim 0.12 with a small, self-contained profile.
MOD_DESC="Neovim 0.12 + LSP, completion, fuzzy find, git signs"
MOD_DEFAULT=yes
MOD_TOOLS="neovim"
MOD_PKGS="git"
# Desktop clipboard support on Wayland.
[[ -n "${WAYLAND_DISPLAY:-}" || "${XDG_SESSION_TYPE:-}" == wayland ]] && MOD_PKGS+=" wl-clipboard"
MOD_DEPS=""

NVIM_APPNAME_SS="supershell-nvim"
NVIM_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/$NVIM_APPNAME_SS"
NVIM_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/$NVIM_APPNAME_SS"
NVIM_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/$NVIM_APPNAME_SS"
NVIM_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/$NVIM_APPNAME_SS"

_editor_files() { (cd "$SS_APP/config/nvim" && find . -type f -name '*.lua' | sed 's|^\./||' | sort); }

mod_install() {
  have git || { apt_update_once; run_root apt-get install -y -qq git; }
  install_tool neovim
  # Desktop clipboard support on Wayland (small package; skipped over SSH-only systems).
  if [[ -n "${WAYLAND_DISPLAY:-}${XDG_SESSION_TYPE:-}" ]] && ! have wl-copy; then
    if apt_installed_version wl-clipboard >/dev/null; then :; else
      apt_update_once
      if run_root apt-get install -y -qq wl-clipboard; then journal_add apt wl-clipboard; apt_record wl-clipboard; fi
    fi
  fi
  local f
  [[ -d "$NVIM_CFG" ]] || journal_add absent "$NVIM_CFG"
  while IFS= read -r f; do
    install_config "$SS_APP/config/nvim/$f" "$NVIM_CFG/$f"
  done < <(_editor_files)
  if [[ -d "$HOME/.config/nvim" ]]; then
    info "You already have ~/.config/nvim — it stays your 'nvim'. The supershell profile is 'snvim'."
  fi
  _editor_plugins
}

# A plugin checkout is complete when it has a commit and no files missing from the
# work tree. A clone killed half-way fails one of the two.
_plugin_complete() {
  git -C "$1" rev-parse -q --verify HEAD >/dev/null 2>&1 &&
    [[ -z "$(git -C "$1" status --porcelain 2>/dev/null | head -1)" ]]
}

# Plugins are cloned from GitHub by vim.pack. On a slow network this must neither
# block forever nor leave half-cloned plugins behind: vim.pack treats any existing
# plugin directory as installed, so a partial clone would stay broken for good.
_editor_plugins() {
  local t="${SUPERSHELL_PLUGIN_TIMEOUT:-180}" pack="$NVIM_DATA/site/pack/core/opt"
  local rc=0 d name removed=0 before=" "
  info "Installing editor plugins (one-time, needs GitHub; gives up after ${t}s)"
  [[ "$SS_DRY_RUN" == 1 ]] && return 0
  have nvim || return 0
  detail "this can take a few minutes on a slow connection"
  # A rollback of this install must also remove plugins it downloaded.
  [[ -e "$NVIM_DATA" ]] || journal_add absent "$NVIM_DATA"
  if [[ -d "$pack" ]]; then for d in "$pack"/*/; do [[ -d "$d" ]] && before+="$(basename "$d") "; done; fi
  NVIM_APPNAME="$NVIM_APPNAME_SS" timeout --kill-after=10 "$t" nvim --headless "+qa" \
    </dev/null >/dev/null 2>&1 || rc=$?
  if [[ -d "$pack" ]]; then
    for d in "$pack"/*/; do
      [[ -d "$d" ]] || continue
      d="${d%/}" name="${d##*/}"
      # Only clean what this run created, or what has no commit at all (never a
      # plugin someone is editing).
      if [[ "$before" != *" $name "* ]] && ! _plugin_complete "$d" ||
         ! git -C "$d" rev-parse -q --verify HEAD >/dev/null 2>&1; then
        rm -rf -- "$d"; removed=$((removed + 1))
      fi
    done
  fi
  if ((rc == 0 && removed == 0)); then
    ok "editor plugins installed"
  elif ((rc == 124 || rc == 137)); then
    warn "Editor plugins: GitHub was too slow, gave up after ${t}s (removed $removed unfinished download(s)).
   Nothing is broken: they install the first time you open nvim, or run: supershell install editor"
  else
    local note=""; ((removed)) && note="; removed $removed unfinished download(s)"
    warn "Could not install editor plugins now (offline?)$note.
   They install automatically the first time you open nvim."
  fi
  return 0
}

mod_remove() {
  local f
  while IFS= read -r f; do remove_config "$NVIM_CFG/$f"; done < <(_editor_files)
  # Remove the profile's own data (plugins, undo history, caches) — never ~/.config/nvim.
  if [[ -d "$NVIM_CFG" ]]; then
    rm -f -- "$NVIM_CFG/nvim-pack-lock.json"
    find "$NVIM_CFG" -depth -type d -empty -delete 2>/dev/null || true
    [[ -d "$NVIM_CFG" ]] && warn "Kept ${NVIM_CFG/#$HOME/\~} (contains files you added)"
  fi
  local d
  for d in "$NVIM_DATA" "$NVIM_STATE" "$NVIM_CACHE"; do
    [[ "$d" == */"$NVIM_APPNAME_SS" ]] && rm -rf -- "$d"
  done
  remove_tool neovim
}

mod_doctor() {
  if have nvim; then
    local v; v="$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    version_ge "$v" 0.12 && check_ok "neovim $v" || check_fail "neovim $v is older than 0.12"
  else check_fail "nvim not found"; fi
  [[ -f "$NVIM_CFG/init.lua" ]] && check_ok "profile at ${NVIM_CFG/#$HOME/\~}" || check_fail "profile missing at ${NVIM_CFG/#$HOME/\~}"
  [[ -d "$NVIM_DATA/site/pack" ]] && check_ok "editor plugins installed" || check_warn "editor plugins not installed yet (open nvim once with network)"
  if have nvim; then
    local err
    err="$(NVIM_APPNAME="$NVIM_APPNAME_SS" timeout 30 nvim --headless "+lua io.stdout:write(#vim.v.errmsg > 0 and vim.v.errmsg or '')" +qa 2>&1 || true)"
    [[ -z "$err" ]] && check_ok "profile loads without errors" || check_fail "profile error: ${err:0:160}"
  fi
  local n=0 s
  for s in bash-language-server pyright gopls yaml-language-server terraform-ls marksman; do
    [[ -x "$NVIM_DATA/mason/bin/$s" ]] || have "$s" && n=$((n+1))
  done
  ((n > 0)) && check_ok "$n language servers available" || check_warn "no language servers yet — in nvim run :SupershellLspInstall"
  return 0
}
