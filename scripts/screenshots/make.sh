#!/usr/bin/env bash
# Regenerate the README screenshots (docs/images/*.png) from REAL output: starship draws
# the prompts (supershell-theme, rendered from this repository), and eza, git, bat, fzf
# and the supershell CLI print the rest. Nothing is drawn by hand.
#
#   scripts/screenshots/make.sh            (needs: starship, eza, git, bat, fzf, tmux,
#                                           google-chrome or chromium, python3)
#
# A throw-away demo home is used: user "dev", project ~/projects/api, clock fixed at
# 09:41 — no personal data, and the same picture every time. Fonts are the machine's
# (JetBrains Mono, Symbols Nerd Font Mono, DejaVu Sans Mono for Arabic).
set -euo pipefail
cd "$(dirname "$0")/../.."
REPO="$PWD" OUT="$PWD/docs/images" COLS=100
mkdir -p "$OUT"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
for c in starship eza git bat fzf tmux python3; do command -v "$c" >/dev/null || { echo "missing: $c" >&2; exit 1; }; done
CHROME="$(command -v google-chrome || command -v chromium || command -v chromium-browser || true)"
[[ -n "$CHROME" ]] || { echo "missing: google-chrome or chromium" >&2; exit 1; }

# fonts, found before HOME moves to the demo home (the page loads them from the files)
FONTS=()
for f in "SS Mono=JetBrains Mono" "SS Icons=Symbols Nerd Font Mono" "SS Arabic=DejaVu Sans Mono"; do
  file="$(fc-match -f '%{file}' "${f#*=}")"
  [[ -r "$file" ]] && FONTS+=(--font "${f%%=*}=$file")
done

# ---- the prompt configs, rendered like supershell does (no user tweaks) -------------
cfg() {   # <palette> <user name> <out>
  sed 's/@DEVOPS_OFF@/false/' config/starship/themes/supershell-theme.toml \
    | sed "s/^palette = .*/palette = \"$1\"/" >"$W/t.toml"
  starship preset nerd-font-symbols >"$W/sym.toml"
  awk -f lib/toml-merge.awk "$W/sym.toml" "$W/t.toml" >"$W/t2.toml"
  awk -f lib/toml-merge.awk config/starship/fallback-nerd.toml "$W/t2.toml" \
    | sed "/^\[username\]/,/^\[/ s/\$user/$2/" \
    | sed 's/^time_format = .*/time_format = "09:41"/' >"$3"
}
cfg supershell dev "$W/user.toml"
cfg supershell-root root "$W/root.toml"

# ---- demo home -------------------------------------------------------------------
D="$W/home"; P="$D/projects/api"; AR="$D/مشاريع"
mkdir -p "$P/src/routes" "$P/tests" "$AR/تقارير"
export HOME="$D" GIT_CONFIG_GLOBAL="$D/.gitconfig" LANG=C.UTF-8 LC_ALL=C.UTF-8 TZ=UTC
git config --global user.name dev; git config --global user.email dev@example.com
git config --global init.defaultBranch main
( cd "$P"
  printf '{\n  "name": "api",\n  "version": "1.4.0",\n  "scripts": { "test": "node --test" }\n}\n' >package.json
  printf '# api\n\nA small HTTP service.\n' >README.md
  printf 'export const health = () => ({ ok: true });\n' >src/routes/health.js
  printf 'import { health } from "./routes/health.js";\n' >src/server.js
  printf 'import test from "node:test";\n' >tests/health.test.js
  printf 'node_modules/\n' >.gitignore
  git init -q && git add -A && git commit -qm "first version"
  printf 'export const health = () => ({ ok: true, version: "1.4.0" });\n' >src/routes/health.js
  printf 'export const users = [];\n' >src/routes/users.js )
printf '# تقرير الربع الأول\n\nتم إطلاق **supershell** بنجاح — *سطر عربي* مع English في نفس السطر.\n\n- الأرقام: ١٢٣ و 123\n' >"$AR/تقارير/ملخص.md"
touch "$AR/خطة 2026.txt" "$AR/عرض تقديمي.pdf"

prompt() {   # <config> <dir> [status] [duration ms]
  (cd "$2" && env -u STARSHIP_SHELL STARSHIP_CONFIG="$1" STARSHIP_CACHE="$W/sc" STARSHIP_LOG=error \
     starship prompt --terminal-width "${WIDTH:-$COLS}" --status "${3:-0}" --cmd-duration "${4:-0}" --jobs 0)
}
EZA=(eza --icons=always --color=always --group-directories-first)

# ---- scenes ----------------------------------------------------------------------
{ prompt "$W/user.toml" "$P"; echo "lt"
  (cd "$P" && "${EZA[@]}" --tree --level=2 .)
  prompt "$W/user.toml" "$P"; echo "git status -sb"
  (cd "$P" && git -c color.status=always status -sb)
  prompt "$W/user.toml" "$P"; echo "sleep 3"
  prompt "$W/user.toml" "$P" 0 3000; echo        # line 2 shows how long it took
} >"$W/hero.ansi"

{ echo "$(prompt "$W/user.toml" "$P" | sed -n 2,3p)supershell theme list"; echo
  for pal in supershell supershell-root pastel tokyo-night catppuccin gruvbox nord dracula rose-pine kanagawa; do
    cfg "$pal" "$([[ $pal == supershell-root ]] && echo root || echo dev)" "$W/p.toml"
    note=""; [[ $pal == supershell ]] && note="  ● yours"; [[ $pal == supershell-root ]] && note="  ◆ root shells"
    printf '\e[1m%s\e[0m%s\n' "$pal" "$note"
    prompt "$W/p.toml" "$P" | grep -m1 .; echo
  done
} >"$W/themes.ansi"

{ prompt "$W/user.toml" "$P"; echo "sudo -i"
  prompt "$W/root.toml" "$D"; echo "whoami"; echo "root"
  prompt "$W/root.toml" "$D"; echo
} >"$W/root.ansi"

{ prompt "$W/user.toml" "$AR"; echo "ls"
  (cd "$AR" && "${EZA[@]}" -1 .)
  prompt "$W/user.toml" "$AR"; echo "bat تقارير/ملخص.md"
  (cd "$AR" && bat --color=always --style=plain --paging=never "تقارير/ملخص.md")
  prompt "$W/user.toml" "$AR"; echo
} >"$W/arabic.ansi"

# the colour chooser: real fzf in tmux, captured with its colours
{ for pal in supershell pastel tokyo-night nord dracula; do
    cfg "$pal" dev "$W/p.toml"
    # like supershell: 4 columns narrower than the window, for fzf's markers
    printf '%s%s\n%s\0' "$pal" "$([[ $pal == supershell ]] && echo "  ● current")" "$(WIDTH=$((COLS - 4)) prompt "$W/p.toml" "$P" | grep -m1 .)"
  done; } >"$W/items"
tmux -L ss-shot -f /dev/null new-session -d -x "$COLS" -y 24 \
  "fzf --read0 --ansi --no-sort --layout=reverse --gap --highlight-line --info=hidden \
     --header 'Your colours — arrows: look · Enter: use · Esc: cancel' <'$W/items'; sleep 5"
sleep 1.5; tmux -L ss-shot send-keys Down; sleep 0.8
{ echo "$(prompt "$W/user.toml" "$P" | sed -n 2,3p)supershell theme colors"
  tmux -L ss-shot capture-pane -e -p | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
} >"$W/chooser.ansi"
tmux -L ss-shot kill-server 2>/dev/null || true

{ echo "$(prompt "$W/user.toml" "$P" | sed -n 2,3p)supershell -h"
  script -qec "'$REPO/supershell' -h" /dev/null </dev/null | tr -d '\r'
} >"$W/help.ansi"

# ---- render -------------------------------------------------------------------------
shot() {   # <name> <title>
  local size; size="$(python3 -I scripts/screenshots/ansi2html.py "$W/$1.ansi" "$W/$1.html" --title "$2" --cols "$COLS" "${FONTS[@]}")"
  timeout 60 "$CHROME" --headless=new --disable-gpu --hide-scrollbars --no-first-run --user-data-dir="$W/chrome" \
    --default-background-color=00000000 --force-device-scale-factor=2 \
    --window-size="${size// /,}" --screenshot="$OUT/$1.png" "file://$W/$1.html" >/dev/null 2>&1
  echo "  docs/images/$1.png"
}
echo "Rendering:"
shot hero    "dev@laptop: ~/projects/api"
shot themes  "supershell theme list"
shot chooser "supershell theme colors"
shot root    "sudo -i"
shot arabic  "dev@laptop: ~/مشاريع"
shot help    "supershell -h"

# social preview (Settings → General → Social preview): 1280×640, title + the hero shot
cat >"$W/social.html" <<HTML
<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;width:1280px;height:640px;overflow:hidden;background:#15161c;font-family:'Ubuntu Sans','DejaVu Sans',sans-serif}
.t{position:absolute;left:72px;top:70px;color:#fff;font-size:76px;font-weight:700;letter-spacing:-1px}
.s{position:absolute;left:76px;top:172px;color:#aab1c0;font-size:28px;line-height:1.4;width:520px}
.bar{position:absolute;left:76px;top:330px;width:440px;height:14px;border-radius:7px;
  background:linear-gradient(90deg,#7B2D8E,#C5487F,#F07E6E,#F7B267,#3E9C9F,#2C5D86)}
.u{position:absolute;left:76px;bottom:64px;color:#7f8796;font-size:22px}
img{position:absolute;right:-150px;top:120px;width:820px}
</style></head><body>
<div class="t">supershell</div>
<div class="s">A modern, careful Bash environment for Ubuntu — while Bash stays Bash.</div>
<div class="bar"></div>
<div class="u">github.com/saeed-morshidy/supershell</div>
<img src="file://$OUT/hero.png">
</body></html>
HTML
timeout 60 "$CHROME" --headless=new --disable-gpu --hide-scrollbars --no-first-run --user-data-dir="$W/chrome" \
  --window-size=1280,640 --screenshot="$OUT/social-preview.png" "file://$W/social.html" >/dev/null 2>&1
echo "  docs/images/social-preview.png"
