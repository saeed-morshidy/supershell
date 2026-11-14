#!/usr/bin/env python3
"""Pick the font size closest to the one asked for at which the prompt bar's glyphs
(powerline arrow U+E0B0, rounded ends U+E0B6 / U+E0B4) fill the terminal line exactly.

    fontfit.py "Cascadia Code NF" 14 96       → prints e.g. 14.5

Why: VTE (Ptyxis, GNOME Terminal) does not draw these glyphs itself — they come from
the font — and it rounds the line height up (ceil of the measured height, baseline at
ceil(ascent)). At some sizes the glyph ends one pixel above the bottom (or below the
top) of the line, and a rounded end shows a small step against the colour bar. The
calculation below follows VTE's own (src/fonts-pangocairo.cc: measure_font and the
Pango metrics check) using Pango, the library VTE uses.

The third argument is the dpi VTE measures at: 96 × the text scaling factor. The
display scale (1.25, 2 …) is not part of it: GTK lays out in logical pixels and the
compositor scales the result, so an exact fit stays exact.
Prints the size it was given when it cannot tell (no PyGObject/Pango, font missing).
"""
import math
import sys


def gaps(family, size, dpi):
    import gi
    gi.require_version("Pango", "1.0")
    gi.require_version("PangoCairo", "1.0")
    from gi.repository import Pango, PangoCairo

    s = Pango.SCALE
    ctx = PangoCairo.FontMap.get_default().create_context()
    PangoCairo.context_set_resolution(ctx, dpi)
    fd = Pango.FontDescription.from_string(f"{family} {size}")
    ctx.set_font_description(fd)
    lay = Pango.Layout.new(ctx)
    # VTE measure_font(): the tallest of U+0021..U+007E, baseline of the sample text
    height = 1
    for c in range(0x21, 0x7F):
        lay.set_text(chr(c), -1)
        _ink, log = lay.get_extents()
        height = max(height, math.ceil(log.height / s))
    lay.set_text("".join(chr(c) for c in range(0x21, 0x7F)), -1)
    ascent = math.ceil(lay.get_baseline() / s)
    # …then the font's metrics, used only when not smaller (VTE issue #163 / g-t #340)
    m = ctx.get_metrics(fd, None)
    ma, mh = math.ceil(m.get_ascent() / s), math.ceil(m.get_height() / s)
    if ma > 0 and mh >= height:
        ascent, height = ma, mh
    worst = 0.0
    for ch in ("", "", ""):
        lay.set_text(ch, -1)
        ink, _log = lay.get_extents()
        base = lay.get_baseline() / s
        top = ink.y / s - base + ascent
        bottom = (ink.y + ink.height) / s - base + ascent
        if ink.height == 0:
            return None                      # glyph missing: cannot tell
        worst = max(worst, top, height - bottom)
    return worst


def main():
    family, size, dpi = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
    asked = f"{size:g}"
    try:
        if gaps(family, size, dpi) is None:
            print(asked)
            return
        # nearest exact size, quarter points, within -1 … +1.5 of the size asked for;
        # on a tie the larger one (easier to read)
        for step in range(0, 7):
            for cand in (size + step * 0.25, size - step * 0.25):
                if cand < 6 or not (size - 1 <= cand <= size + 1.5):
                    continue
                g = gaps(family, cand, dpi)
                if g is not None and g <= 0:
                    print(f"{cand:g}")
                    return
    except Exception:
        pass
    print(asked)


if __name__ == "__main__":
    main()
