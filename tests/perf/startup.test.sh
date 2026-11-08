# shellcheck shell=bash
# Performance of supershell's own code. Tools are stubs here, so these numbers
# measure the framework overhead only; real numbers come from `supershell bench`
# on the target laptop (docs/reports/performance.md).

_ms() { # mean ms of N interactive starts
  local n="$1" i s e total=0; shift
  for ((i = 0; i <= n; i++)); do
    s=${EPOCHREALTIME/./}; env "$@" bash -i -c exit </dev/null >/dev/null 2>&1; e=${EPOCHREALTIME/./}
    ((i == 0)) || total=$((total + e - s))
  done
  echo $((total / n / 1000))
}

test_framework_overhead_is_small() {
  t_ubuntu_bashrc
  ss install core git devops --yes >/dev/null 2>&1 || t_fail install
  bash -i -c exit </dev/null >/dev/null 2>&1   # build the init cache
  local off on
  off="$(_ms 20 SUPERSHELL_DISABLE=1)"
  on="$(_ms 20 HOME="$HOME")"
  mkdir -p "$T_REPO/tests/results"
  printf 'framework_overhead off=%sms on=%sms delta=%sms (stub tools)\n' "$off" "$on" "$((on - off))" | tee -a "$T_REPO/tests/results/perf.txt" >&2
  ((on - off < 40)) || t_fail "supershell adds $((on - off)) ms of its own start-up time (budget 40 ms)"
}

test_memory_overhead_is_small() {
  t_ubuntu_bashrc
  ss install core git devops --yes >/dev/null 2>&1 || t_fail install
  local a b
  a="$(SUPERSHELL_DISABLE=1 bash -i -c 'ps -o rss= -p $$' </dev/null 2>/dev/null | tr -d ' ')"
  b="$(bash -i -c 'ps -o rss= -p $$' </dev/null 2>/dev/null | tr -d ' ')"
  printf 'rss off=%sKB on=%sKB delta=%sKB\n' "$a" "$b" "$((b - a))" | tee -a "$T_REPO/tests/results/perf.txt" >&2
  ((b - a < 3000)) || t_fail "supershell adds $((b - a)) KB per shell (budget 3 MB)"
}

test_no_background_processes_after_startup() {
  ss install core git devops --yes >/dev/null 2>&1 || t_fail install
  local out; out="$(bash -i -c 'sleep 0.3; ps -o pid=,comm= --ppid $$ | grep -v -e "ps$" -e "grep$" -e "sleep$" || true' </dev/null 2>/dev/null)"
  assert_eq "$out" "" "background processes left by start-up"
}

test_bench_command_runs() {
  ss install core --yes >/dev/null 2>&1 || t_fail install
  local out; out="$(ss bench 5 2>&1)" || t_fail "bench failed: $out"
  assert_contains "$out" "Overhead added by supershell"
}
