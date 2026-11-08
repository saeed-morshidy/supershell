#!/usr/bin/env bash
# Real end-to-end run on a real Ubuntu (CI container ubuntu:26.04, or a VM).
# Installs real packages and downloads real releases — never run it on your laptop.
#   tests/e2e/run.sh            (as a normal user with passwordless sudo)
set -uo pipefail
cd "$(dirname "$0")/../.."
REPO="$PWD" pass=0 fail=0 out="$REPO/tests/results/e2e.md"
mkdir -p "$(dirname "$out")"
step() { local name="$1"; shift
  if "$@" >"/tmp/e2e.$$" 2>&1; then pass=$((pass+1)); echo "| $name | ✅ |" >>"$out"; echo "ok   $name"
  else fail=$((fail+1)); echo "| $name | ❌ |" >>"$out"; echo "FAIL $name"; tail -30 "/tmp/e2e.$$" | sed 's/^/     /'; fi; }
{ echo "# e2e on $(. /etc/os-release; echo "$PRETTY_NAME") — $(date -Is)"; echo; echo "| step | result |"; echo "|---|---|"; } >"$out"

cp ~/.bashrc /tmp/bashrc.orig 2>/dev/null || touch /tmp/bashrc.orig
step "install defaults (core git editor fonts devops)" ./supershell install --yes
export PATH="$HOME/.local/bin:$PATH"
step "doctor passes" supershell doctor
step "interactive start-up is silent" bash -c '[[ -z "$(bash -ic true 2>&1 </dev/null | grep -v -e "no job control" -e "terminal process group")" ]]'
step "prompt, z, ll are active" bash -ic 'type -t z && alias ll && [[ -n "$STARSHIP_SHELL" ]]' </dev/null
step "standard commands unchanged" bash -ic '[[ "$(type -t ls cat grep find cd | sort -u | tr "\n" " ")" != *alias* || "$(alias ls 2>/dev/null)" == *"--color=auto"* ]]' </dev/null
step "neovim >= 0.12" bash -c 'nvim --version | head -1 | grep -qE "v0\.(1[2-9]|[2-9][0-9])"'
step "neovim profile loads cleanly" bash -c 'err="$(NVIM_APPNAME=supershell-nvim nvim --headless "+lua io.stdout:write(vim.v.errmsg)" +qa 2>&1)"; [[ -z "$err" ]] || { echo "$err"; false; }'
step "neovim keeps Arabic text intact" bash -c 'printf "سطر عربي mixed English\n" >/tmp/a.txt; NVIM_APPNAME=supershell-nvim nvim --headless /tmp/a.txt "+normal! A ✓" +wq; [[ "$(cat /tmp/a.txt)" == "سطر عربي mixed English ✓" ]]'
step "neovim termbidi on" bash -c '[[ "$(NVIM_APPNAME=supershell-nvim nvim --headless "+lua io.stdout:write(tostring(vim.o.termbidi))" +qa 2>&1)" == true ]]'
step "git diff goes through delta" bash -c 'cd "$(mktemp -d)" && git init -q && echo a>f && git add f && git -c user.email=t@t -c user.name=t commit -qm a && echo b>f && git config --includes --get core.pager | grep -q delta && git -c color.ui=always diff | head -1 >/dev/null'
step "bench" bash -c 'supershell bench 10 | tee -a '"$out"
step "uninstall restores ~/.bashrc exactly" bash -c 'supershell uninstall --yes --purge-packages && cmp ~/.bashrc /tmp/bashrc.orig'
step "reinstall core after uninstall" ./supershell install core --yes
{ echo; echo "**$pass passed, $fail failed**"; } >>"$out"
echo "$pass passed, $fail failed"; ((fail == 0))
