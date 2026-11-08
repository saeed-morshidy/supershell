#!/usr/bin/env bash
# Maintainers: download every release asset in manifest/tools.ini, verify it against
# the upstream checksum file when one exists, and pin its SHA-256 in the manifest.
#
#   scripts/update-manifest.sh            pin all tools
#   scripts/update-manifest.sh neovim     pin one tool
#   scripts/update-manifest.sh --latest   only show the newest upstream versions (needs gh)
#
# The resulting diff is a security-relevant change: open a PR, never push directly.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
SS_ROOT="$PWD"
. lib/common.sh; . lib/os.sh; . lib/state.sh; . lib/backup.sh; . lib/tools.sh
SS_MANIFEST="$SS_ROOT/manifest/tools.ini"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
# Same rule as the installer: never hang on a stalled connection; don't retry a 404.
CURL=(curl -fsSL --proto '=https' --tlsv1.2 --connect-timeout 15 --speed-limit 1024 --speed-time 30
      --max-time 900 --retry 3 --retry-delay 3 --retry-connrefused)

tools=("$@")
if [[ "${1:-}" == --latest ]]; then
  have gh || die "--latest needs the GitHub CLI (gh)"
  for t in $(grep -oE '^\[[a-z-]+\]' "$SS_MANIFEST" | tr -d '[]'); do
    url="$(manifest_get "$t" url.x86_64)"; [[ "$url" == https://github.com/* ]] || continue
    repo="$(cut -d/ -f4,5 <<<"$url")"
    latest="$(gh release view -R "$repo" --json tagName -q .tagName 2>/dev/null || echo '?')"
    printf '%-14s pinned %-14s latest %s\n' "$t" "$(manifest_get "$t" version)" "$latest"
  done
  exit 0
fi
((${#tools[@]})) || mapfile -t tools < <(grep -oE '^\[[a-z-]+\]' "$SS_MANIFEST" | tr -d '[]')

set_key() { # tool key value — rewrite one key inside one section
  awk -v t="[$1]" -v k="$2" -v v="$3" '
    /^\[/ { insec = ($0 == t) }
    insec { i = index($0, "="); if (i) { kk = substr($0, 1, i - 1); gsub(/[[:space:]]+/, "", kk); if (kk == k) { print k " = " v; next } } }
    { print }' "$SS_MANIFEST" >"$work/m" && mv "$work/m" "$SS_MANIFEST"
}

for t in "${tools[@]}"; do
  for arch in x86_64 aarch64; do
    url="$(manifest_get "$t" "url.$arch")"; [[ -n "$url" ]] || continue
    f="$work/${url##*/}"
    info "$t ($arch): $url"
    "${CURL[@]}" -o "$f" "$url" || die "download failed: $url"
    sum="$(sha256sum "$f" | cut -d' ' -f1)"
    sums="$(manifest_get "$t" sums)"
    if [[ -n "$sums" ]]; then
      sums="${sums//\{url\}/$url}"
      "${CURL[@]}" -o "$work/sums" "$sums" || die "checksum file missing: $sums"
      grep -q "$sum" "$work/sums" || die "$t: $sum does not match upstream $sums"
      detail "matches upstream checksum file"
    else
      warn "$t: upstream publishes no checksums — pinning what was downloaded now (review carefully)"
    fi
    if [[ "$url" =~ ^https://github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/ ]]; then
      # GitHub publishes a SHA-256 digest for every release asset: cross-check it.
      api="https://api.github.com/repos/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/releases/tags/${BASH_REMATCH[3]}"
      "${CURL[@]}" -H 'Accept: application/vnd.github+json' -o "$work/rel.json" "$api" \
        || die "$t: cannot fetch release metadata: $api"
      digest="$(python3 -I - "$work/rel.json" "${url##*/}" <<'PY'
import json, sys
for a in json.load(open(sys.argv[1])).get("assets", []):
    if a.get("name") == sys.argv[2]:
        print(a.get("digest") or "")
PY
)"
      [[ "$digest" == "sha256:$sum" ]] || die "$t: GitHub asset digest '${digest:-none}' does not equal sha256:$sum"
      detail "matches GitHub asset digest"
    fi
    set_key "$t" "sha256.$arch" "$sum"
    ok "$t $arch $sum"
    rm -f "$f"
  done
done
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then git --no-pager diff --stat -- manifest/tools.ini; fi
