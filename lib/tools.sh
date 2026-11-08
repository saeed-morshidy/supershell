# shellcheck shell=bash
# Installing individual tools: apt first (when new enough), otherwise a pinned,
# checksum-verified GitHub release. Never pipes anything into a shell.

SS_MANIFEST="${SUPERSHELL_MANIFEST:-$SS_ROOT/manifest/tools.ini}"
_SS_APT_UPDATED=0

# manifest_get <tool> <key>  — prints the value ({version} expanded), or nothing.
manifest_get() {
  local tool="$1" key="$2" val ver
  val="$(awk -v t="[$tool]" -v k="$key" '
    /^[[:space:]]*#/ { next }
    /^\[/ { insec = ($0 == t); next }
    insec {
      i = index($0, "=")
      if (i == 0) next
      kk = substr($0, 1, i - 1); gsub(/[[:space:]]+/, "", kk)
      if (kk == k) { v = substr($0, i + 1); sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v); print v; exit }
    }' "$SS_MANIFEST")"
  if [[ "$key" != version && "$val" == *"{version}"* ]]; then
    ver="$(manifest_get "$tool" version)"
    val="${val//\{version\}/$ver}"
  fi
  printf '%s' "$val"
}

manifest_has() { grep -qx -- "\[$1\]" "$SS_MANIFEST"; }

# ---- apt ----------------------------------------------------------------------
apt_installed_version() {
  local out
  out="$(dpkg-query -W -f='${Status}\t${Version}' "$1" 2>/dev/null)" || return 1
  [[ "$out" == "install ok installed"* ]] || return 1
  printf '%s' "${out#*$'\t'}"
}

apt_candidate_version() {
  local c
  c="$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')"
  [[ -n "$c" && "$c" != "(none)" ]] || return 1
  printf '%s' "$c"
}

version_ge() { dpkg --compare-versions "$1" ge "$2"; }

apt_update_once() {
  [[ $_SS_APT_UPDATED == 1 ]] && return 0
  info "Refreshing the apt package index"
  run_root apt-get update -qq || die "apt-get update failed — check your network or /etc/apt/sources.list.d"
  _SS_APT_UPDATED=1
}

# Make 'bat'/'fd' available when Ubuntu ships them as 'batcat'/'fdfind'.
_link_apt_bins() {
  local tool="$1" pair from to
  for pair in $(manifest_get "$tool" apt_bins); do
    from="${pair%%:*}" to="${pair##*:}"
    if ! have "$to" && have "$from"; then
      link_bin "$(command -v "$from")" "$to"
    fi
  done
}

# ---- release downloads -----------------------------------------------------------
download() {
  local url="$1" out="$2"
  have curl || die "curl is required to download '$url' (sudo apt install curl)"
  # Never hang: give up on a connection that delivers < 1 KB/s for 30 s, retry
  # transient errors (e.g. HTTP 503, resets), and show progress on a terminal.
  local show=(-s)
  [[ -t 2 ]] && show=(--progress-bar)
  local rc=0
  curl -fSL "${show[@]}" --proto '=https' --tlsv1.2 --connect-timeout 15 \
       --speed-limit 1024 --speed-time 30 --max-time 900 \
       --retry 3 --retry-delay 3 --retry-connrefused -o "$out" "$url" || rc=$?
  if ((rc != 0)); then
    rm -f -- "$out"
    if ((rc == 22)); then
      die "Download failed: $url
   The server says this file doesn't exist (HTTP error). The manifest may need updating —
   please open an issue."
    fi
    die "Download failed: $url
   The connection failed or stalled (curl error $rc). Run the same command again —
   everything already installed stays, nothing half-downloaded is used — or download the
   file in a browser into ~/.cache/supershell/dl/ and re-run."
  fi
}

sha256_of() { sha256sum -- "$1" | awk '{print $1}'; }

# verify_asset <tool> <file> <url>
verify_asset() {
  local tool="$1" file="$2" url="$3" want got sums_url sums_file name
  got="$(sha256_of "$file")"
  want="$(manifest_get "$tool" "sha256.$OS_ARCH")"
  if [[ -n "$want" ]]; then
    [[ "$got" == "$want" ]] || { rm -f -- "$file"; die "Checksum mismatch for $tool ($url)
   expected $want
   got      $got
   The file was deleted. This can mean a corrupted download or a tampered release."; }
    detail "sha256 verified against the pinned manifest value"
    return 0
  fi
  sums_url="$(manifest_get "$tool" sums)"
  if [[ -n "$sums_url" ]]; then
    sums_url="${sums_url//\{url\}/$url}"
    sums_file="$(mktemp "$SS_CACHE/sums.XXXXXX")"
    download "$sums_url" "$sums_file"
    name="${url##*/}"
    want="$(awk -v n="$name" '{f=$2; sub(/^\*/,"",f); sub(/^.*\//,"",f)} f==n || NF==1 {print $1; exit}' "$sums_file")"
    rm -f -- "$sums_file"
    [[ -n "$want" && "$got" == "$want" ]] || { rm -f -- "$file"; die "Checksum mismatch for $tool against upstream checksums ($sums_url)"; }
    warn "$tool: verified against the upstream checksum file (no pinned hash in the manifest yet)"
    return 0
  fi
  if [[ "${SUPERSHELL_ALLOW_UNVERIFIED:-0}" == 1 ]]; then
    warn "$tool: NOT verified (no pinned hash, no upstream checksums) — allowed by SUPERSHELL_ALLOW_UNVERIFIED=1"
    return 0
  fi
  rm -f -- "$file"
  die "$tool $(manifest_get "$tool" version): no pinned SHA-256 and no upstream checksum file.
   Refusing to install an unverified download. Maintainers: run scripts/update-manifest.sh"
}

# Symlink $1 into ~/.local/bin/$2 without clobbering anything we don't own.
link_bin() {
  local target="$1" name="$2" link cur
  link="$SS_BIN/$name"
  mkdir -p "$SS_BIN"
  if [[ -L "$link" ]]; then
    cur="$(readlink "$link")"
    if [[ "$cur" != "$SS_DATA"/* && "$cur" != /usr/bin/* ]]; then
      warn "~/.local/bin/$name already points to $cur — leaving it alone"; return 0
    fi
  elif [[ -e "$link" ]]; then
    warn "~/.local/bin/$name exists and is not ours — leaving it alone"; return 0
  else
    journal_add absent "$link"
  fi
  run ln -sfn -- "$target" "$link"
  # a cached `<tool> init` script may embed the previous binary's path
  rm -f -- "$SS_CACHE/init/$name.bash"
}

_extract() {
  local file="$1" dir="$2"
  case "$file" in
    *.tar.gz|*.tgz) tar -xzf "$file" -C "$dir" ;;
    *.tar.xz)       tar -xJf "$file" -C "$dir" ;;
    *.zip)          have unzip || die "unzip is required"; unzip -q "$file" -d "$dir" ;;
    *)              cp -- "$file" "$dir/" ;;
  esac
  # Flatten a single top-level directory.
  local entries=("$dir"/*)
  if [[ ${#entries[@]} -eq 1 && -d "${entries[0]}" ]]; then
    local inner="${entries[0]}" tmp="$dir.flat"
    mv -- "$inner" "$tmp" && rmdir -- "$dir" && mv -- "$tmp" "$dir"
  fi
}

install_release() {
  local tool="$1" ver url dest stage file pair src name
  ver="$(manifest_get "$tool" version)"
  url="$(manifest_get "$tool" "url.$OS_ARCH")"
  [[ -n "$url" ]] || die "No release of $tool for $OS_ARCH in the manifest"
  dest="$SS_OPT/$tool/$ver"
  if [[ -d "$dest" ]]; then
    detail "$tool $ver already present"
  else
    info "Downloading $tool $ver"
    [[ "$SS_DRY_RUN" == 1 ]] && { detail "dry-run: $url"; return 0; }
    mkdir -p "$SS_CACHE/dl" "$SS_OPT/$tool"
    file="$SS_CACHE/dl/${url##*/}"
    # A file already in the download folder (e.g. fetched with a browser on a slow
    # network) is reused — it still has to pass the same checksum verification.
    if [[ -s "$file" ]]; then
      detail "using ${file/#$HOME/\~} (will be verified)"
    else
      download "$url" "$file"
    fi
    verify_asset "$tool" "$file" "$url" || { rm -f -- "$file"; return 1; }
    stage="$SS_OPT/$tool/.staging-$$"
    rm -rf -- "$stage"; mkdir -p "$stage"
    journal_add created "$stage"
    _extract "$file" "$stage"
    journal_add created "$dest"
    mv -- "$stage" "$dest"
    # Delete the archive only once the whole run succeeds (a browser-downloaded file
    # must survive a rollback).
    if journal_active; then journal_add cleanup "$file"; else rm -f -- "$file"; fi
  fi
  for pair in $(manifest_get "$tool" bins); do
    src="${pair%%:*}" name="${pair##*:}"; name="${name##*/}"
    [[ -e "$dest/$src" ]] || die "$tool: expected '$src' inside the release archive"
    chmod +x "$dest/$src"
    link_bin "$dest/$src" "$name"
  done
  tool_record "$tool" release "$ver" "$dest"
  ok "$tool $ver (release, verified)"
}

# install_tool <tool> — the one entry point modules use.
install_tool() {
  local tool="$1" pkg min have_v cand
  manifest_has "$tool" || die "internal: '$tool' is not in the manifest"
  pkg="$(manifest_get "$tool" apt)"
  min="$(manifest_get "$tool" apt_min)"
  if [[ -n "$pkg" ]]; then
    if have_v="$(apt_installed_version "$pkg")" && { [[ -z "$min" ]] || version_ge "$have_v" "$min"; }; then
      detail "$tool: using installed apt package $pkg $have_v"
      tool_record "$tool" apt-existing "$have_v" "$pkg"
      _link_apt_bins "$tool"
      return 0
    fi
    # No `apt-get update` here: the batch step at the start of the run refreshed the
    # index if anything was needed, so this never asks for sudo unexpectedly.
    if cand="$(apt_candidate_version "$pkg")" && { [[ -z "$min" ]] || version_ge "$cand" "$min"; }; then
      info "Installing $pkg $cand from Ubuntu"
      run_root apt-get install -y -qq --no-install-recommends "$pkg" \
        || die "apt failed to install $pkg. Run 'sudo apt-get install $pkg' to see the full error."
      journal_add apt "$pkg"
      apt_record "$pkg"
      tool_record "$tool" apt "$cand" "$pkg"
      _link_apt_bins "$tool"
      ok "$tool $cand (apt)"
      return 0
    fi
    detail "$tool: apt has ${cand:-no package} (need >= ${min:-any}) — using the pinned release"
  fi
  install_release "$tool"
}

# Remove a tool we installed from a release (apt packages are handled separately).
remove_tool() {
  local tool="$1" info_line src loc link
  info_line="$(tool_info "$tool")" || true
  [[ -n "$info_line" ]] || return 0
  src="$(cut -f2 <<<"$info_line")"; loc="$(cut -f4 <<<"$info_line")"
  if [[ "$src" == release ]]; then
    for link in "$SS_BIN"/*; do
      [[ -L "$link" && "$(readlink "$link")" == "$SS_OPT/$tool/"* ]] && run rm -f -- "$link"
    done
    safe_rm "$SS_OPT/$tool"
    detail "removed $tool (${loc/#$HOME/\~})"
  fi
  # shim links such as ~/.local/bin/bat -> /usr/bin/batcat
  local pair to
  for pair in $(manifest_get "$tool" apt_bins); do
    to="${pair##*:}"
    [[ -L "$SS_BIN/$to" && "$(readlink "$SS_BIN/$to")" == /usr/bin/* ]] && run rm -f -- "$SS_BIN/$to"
  done
  tool_forget "$tool"
}
