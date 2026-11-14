#!/usr/bin/env python3
"""Turn a terminal transcript with ANSI colour codes into a terminal-window HTML page.

    ansi2html.py <transcript> <out.html> --title "…" --cols 100

The transcript is real program output (starship, eza, git, bat, supershell) captured
by make.sh. Only SGR colour codes are interpreted; everything else is dropped. Fonts are
the ones installed on the machine (JetBrains Mono, Symbols Nerd Font Mono for icons,
DejaVu Sans Mono for Arabic), so the picture matches a real terminal.
"""
import argparse
import html
import re

# Terminal colours (a dark theme close to Ptyxis' default)
BG, FG = "#1d1f27", "#d8dee9"
BASE16 = ["#2e3440", "#e06c75", "#98c379", "#e5c07b", "#61afef", "#c678dd", "#56b6c2", "#d8dee9",
          "#5c6370", "#ff7a85", "#b5e48c", "#ffd479", "#82c4ff", "#dda0ff", "#7fd3dc", "#ffffff"]


def xterm256(n):
    if n < 16:
        return BASE16[n]
    if n < 232:
        n -= 16
        r, g, b = n // 36, (n // 6) % 6, n % 6
        c = lambda v: 0 if v == 0 else 55 + v * 40
        return "#%02x%02x%02x" % (c(r), c(g), c(b))
    v = 8 + (n - 232) * 10
    return "#%02x%02x%02x" % (v, v, v)


class State:
    def __init__(self):
        self.reset()

    def reset(self):
        self.fg = self.bg = None
        self.bold = self.dim = self.italic = self.underline = self.reverse = False

    def css(self):
        s = []
        fg, bg = self.fg, self.bg
        if self.reverse:   # SGR 7, as a terminal does it: the defaults swap too
            fg, bg = bg or BG, fg or FG
        if fg: s.append(f"color:{fg}")
        if bg: s.append(f"background:{bg}")
        if self.bold: s.append("font-weight:700")
        if self.dim: s.append("opacity:.6")
        if self.italic: s.append("font-style:italic")
        if self.underline: s.append("text-decoration:underline")
        return ";".join(s)

    def apply(self, params):
        p = [int(x) if x else 0 for x in params.split(";")] if params else [0]
        i = 0
        while i < len(p):
            c = p[i]
            if c == 0: self.reset()
            elif c == 1: self.bold = True
            elif c == 2: self.dim = True
            elif c == 3: self.italic = True
            elif c == 4: self.underline = True
            elif c == 7: self.reverse = True
            elif c == 27: self.reverse = False
            elif c == 22: self.bold = self.dim = False
            elif c == 23: self.italic = False
            elif c == 24: self.underline = False
            elif 30 <= c <= 37: self.fg = BASE16[c - 30]
            elif 90 <= c <= 97: self.fg = BASE16[c - 90 + 8]
            elif 40 <= c <= 47: self.bg = BASE16[c - 40]
            elif 100 <= c <= 107: self.bg = BASE16[c - 100 + 8]
            elif c == 39: self.fg = None
            elif c == 49: self.bg = None
            elif c in (38, 48) and i + 1 < len(p):
                if p[i + 1] == 5 and i + 2 < len(p):
                    col = xterm256(p[i + 2]); i += 2
                elif p[i + 1] == 2 and i + 4 < len(p):
                    col = "#%02x%02x%02x" % tuple(p[i + 2:i + 5]); i += 4
                else:
                    col = None
                if c == 38: self.fg = col
                else: self.bg = col
            i += 1


SGR = re.compile(r"\x1b\[([0-9;]*)m")
OTHER = re.compile(r"\x1b\][^\x07\x1b]*(\x07|\x1b\\)|\x1b\[[0-9;?]*[A-Za-z]|\x1b[()][A-Z0-9]|[\x01\x02]")


# Icons (Private Use Area) take exactly one cell in a terminal; in a browser the icon
# font's glyphs are a little wider than the text font's — so each gets a 1ch box.
PUA = re.compile("([\ue000-\uf8ff\U000f0000-\U000fffff])")


def esc(text):
    # LRM on both sides: an inline-block is a neutral for the bidi algorithm, while the
    # icon itself (Private Use Area) is a strong left-to-right character, as in VTE —
    # without the marks an Arabic folder name would pull the bar around it.
    return PUA.sub('\u200e<span class="ic">\\1</span>\u200e', html.escape(text))


def line_html(line, st):
    out, pos = [], 0
    line = OTHER.sub(lambda m: m.group(0) if m.group(0).endswith("m") and m.group(0).startswith("\x1b[") else "", line)
    for m in SGR.finditer(line):
        if m.start() > pos:
            out.append(f'<span style="{st.css()}">{esc(line[pos:m.start()])}</span>')
        st.apply(m.group(1))
        pos = m.end()
    if pos < len(line):
        out.append(f'<span style="{st.css()}">{esc(line[pos:])}</span>')
    return "".join(out) or "&#8203;"


def main():
    a = argparse.ArgumentParser()
    a.add_argument("src"); a.add_argument("out")
    a.add_argument("--title", default="supershell")
    a.add_argument("--cols", type=int, default=100)
    a.add_argument("--font-size", type=float, default=15)
    a.add_argument("--font", action="append", default=[],
                   help="FAMILY=/path/to/font.ttf, loaded from the file (fontconfig may not see it)")
    args = a.parse_args()
    text = open(args.src, encoding="utf-8").read().strip("\n")
    st = State()
    rows = "\n".join(f'<div class="l">{line_html(l, st)}</div>' for l in text.split("\n"))
    faces = "".join(f"@font-face{{font-family:'{f.split('=',1)[0]}';src:url('file://{f.split('=',1)[1]}')}}\n" for f in args.font)
    mono = "'SS Mono','SS Ends','SS Icons','SS Arabic','JetBrains Mono','Symbols Nerd Font Mono','DejaVu Sans Mono',monospace"
    page = f"""<!doctype html><html><head><meta charset="utf-8"><style>
{faces}
html,body{{margin:0;background:transparent}}
.wrap{{padding:28px 34px 40px}}
.win{{font-family:{mono};width:calc({args.cols}ch + 64px);background:{BG};border-radius:12px;overflow:hidden;
  box-shadow:0 18px 50px rgba(0,0,0,.35),0 0 0 1px rgba(255,255,255,.06)}}
.bar{{height:36px;display:flex;align-items:center;gap:8px;padding:0 14px;background:#2a2d37;
  font:13px/1 'Ubuntu Sans','DejaVu Sans',sans-serif;color:#aab1c0}}
.dot{{width:12px;height:12px;border-radius:50%}}
.title{{flex:1;text-align:center;margin-right:52px}}
.term{{padding:14px 22px 18px;color:{FG};font-family:{mono};
  font-size:{args.font_size}px;line-height:1.5;font-variant-ligatures:none}}
.l{{white-space:pre;direction:ltr;min-height:1.5em}}
.ic{{display:inline-block;width:1ch;overflow:visible;text-align:center}}
.term, .win{{font-size:{args.font_size}px}}
</style></head><body><div class="wrap"><div class="win">
<div class="bar"><span class="dot" style="background:#ff5f57"></span><span class="dot" style="background:#febc2e"></span><span class="dot" style="background:#28c840"></span><span class="title">{html.escape(args.title)}</span></div>
<div class="term">
{rows}
</div></div></div></body></html>"""
    open(args.out, "w", encoding="utf-8").write(page)
    # window size for the screenshot: JetBrains Mono is 0.6em wide; line-height 1.5
    n = text.count("\n") + 1
    width = round(args.cols * args.font_size * 0.6) + 64 + 68 + 4
    height = round(n * args.font_size * 1.5) + 36 + 32 + 68 + 4
    print(width, height)


if __name__ == "__main__":
    main()
