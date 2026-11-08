#!/usr/bin/env bash
# Run the supershell test suite.   tests/run.sh [unit|integration|arabic|perf] [-k pattern]
set -uo pipefail
cd "$(dirname "$0")"
groups=(unit integration arabic perf) filter=""
while (($#)); do
  case "$1" in -k) filter="$2"; shift 2 ;; *) groups=("$1"); shift ;; esac
done
pass=0 fail=0 skip=0 report="results/latest.md" failed=()
mkdir -p results
{ echo "# supershell test results"; echo; echo "- date: $(date -Is)"; echo "- host: $(. /etc/os-release; echo "$PRETTY_NAME") / bash $BASH_VERSION"; echo
  echo "| group | test | result |"; echo "|---|---|---|"; } >"$report"
for g in "${groups[@]}"; do
  for f in "$g"/*.test.sh; do
    [[ -f "$f" ]] || continue
    mapfile -t tests < <(bash -c "source lib/harness.sh; source '$f'; declare -F" | awk '$3 ~ /^test_/ {print $3}')
    for t in "${tests[@]}"; do
      [[ -n "$filter" && "$t" != *"$filter"* && "$f" != *"$filter"* ]] && continue
      out="$(bash -c "source lib/harness.sh; source '$f'; t_sandbox; trap t_cleanup EXIT; set -e; $t" 2>&1)"; rc=$?
      case $rc in
        0)  pass=$((pass+1)); printf '  ok    %-12s %s\n' "$g" "$t"; echo "| $g | $t | ✅ pass |" >>"$report" ;;
        77) skip=$((skip+1)); printf '  skip  %-12s %s  — %s\n' "$g" "$t" "$(grep -o 'SKIP: .*' <<<"$out" | head -1 | cut -c7-)"
            echo "| $g | $t | ⏭️ skipped — $(grep -o 'SKIP: .*' <<<"$out" | head -1 | cut -c7-) |" >>"$report" ;;
        *)  fail=$((fail+1)); failed+=("$g/$t"); printf '  FAIL  %-12s %s\n' "$g" "$t"; printf '%s\n' "$out" | tail -15 | sed 's/^/        /'
            echo "| $g | $t | ❌ fail |" >>"$report" ;;
      esac
    done
  done
done
{ echo; echo "**$pass passed, $fail failed, $skip skipped**"; } >>"$report"
echo; echo "$pass passed, $fail failed, $skip skipped   (report: tests/$report)"
((fail == 0))
