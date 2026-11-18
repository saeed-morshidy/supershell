#!/usr/bin/env python3
"""Generate config/fonts/SupershellEnds.ttf: the rounded ends of the prompt bar.

    python3 scripts/gen-ends-font.py            (needs fontTools: apt install python3-fonttools)

The problem it solves: the usual rounded ends (U+E0B6 / U+E0B4) are glyphs drawn in the
bar's colour on the terminal background. VTE rounds the line height to whole pixels,
the glyph does not follow, and at many sizes (and every zoom step) the end stops a
pixel short of the bar — a visible step.

What this font does instead: the end's cell gets the bar's colour as its *background*
(the prompt prints it with reverse video), which VTE fills to the exact cell edges like
the rest of the bar. On top, this font draws the two outside corners — the part that is
not the rounded end — and reverse video paints them in the terminal's own background
colour. The corners reach past the cell (OVER below) and VTE clips them at the next
line, where they land on the terminal background and cannot be seen. So the end always
meets the bar exactly, whatever the size, zoom, palette or terminal colours.

Code points (unused by Nerd Fonts, in the Private Use Area, one cell wide):
    U+E1F0  left end   — the bar starts at the right half of the cell, round on the left
    U+E1F1  right end  — mirror image

The shape is drawn for Cascadia Code NF's line (ascent 1900, descent 480 of 2048
units, cell 1200 wide), the default terminal font. Other fonts have other line
proportions: the round is a little off, and a 1px step can show at some sizes.
"""
import math
import os
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen

UPM = 2048
ASC, DESC = 1900, 480          # Cascadia Code NF (hhea = typo, USE_TYPO_METRICS)
W = 1200                       # Cascadia Code NF advance width
OVER = 200                     # how far the corners reach past the line, top and bottom
SIDE = 300                     # how far the corners reach past the outer side
LIP = 100                      # see corners()
REACH = 60                     # the round itself reaches this far past the line (½ px at 14 pt)
LEFT, RIGHT = 0xE1F0, 0xE1F1


def arc(rx, ry, cx, cy, t0, t1, n):
    """Cubic Béziers along an ellipse from angle t0 to t1 (n pieces)."""
    out = []
    for i in range(n):
        a0 = t0 + (t1 - t0) * i / n
        a1 = t0 + (t1 - t0) * (i + 1) / n
        k = 4 / 3 * math.tan((a1 - a0) / 4)
        pt = lambda t: (cx + rx * math.cos(t), cy + ry * math.sin(t))
        d = lambda t: (-rx * math.sin(t), ry * math.cos(t))
        (x0, y0), (x1, y1) = pt(a0), pt(a1)
        (dx0, dy0), (dx1, dy1) = d(a0), d(a1)
        out.append(((x0 + k * dx0, y0 + k * dy0), (x1 - k * dx1, y1 - k * dy1), (x1, y1)))
    return out


def corners(pen, mirror):
    """The cell minus a full half circle (radius = half the line, the cell width
    sideways, reaching REACH past the line), plus the overshoot past the line's top,
    bottom and outer side.

    VTE puts the line's top up to a pixel above the font's own (it rounds the line
    height up), so the shape cannot end exactly at the font's top. It does this: the
    round runs as a true half circle from the font's bottom to its top, meeting the
    top LIP units short of the inner edge; from there the corner goes straight up, past
    the line. Whatever VTE does, the bar colour shows in that thin LIP strip at the very
    top and bottom rows — continuing the bar — and never a step."""
    h = (ASC + DESC) / 2              # half the line
    cy = ASC - h
    # ellipse centred on the inner edge, through (W - LIP, ±(h + REACH)): sideways
    # radius W. REACH splits the difference between the two ways VTE can round the line
    # (exactly on the font's edge, or a pixel past it): either way what is left is half
    # a pixel at most, which antialiasing makes invisible.
    t0 = math.acos(LIP / W)           # angle where it meets the line's top / bottom
    ry = (h + REACH) / math.sin(t0)
    top, bot = ASC + OVER, -DESC - OVER

    def p(x, y):                      # left end; the right end is its mirror image
        return (round(W - x if mirror else x), round(y))

    pen.moveTo(p(W - LIP, top))
    pen.lineTo(p(-SIDE, top))
    pen.lineTo(p(-SIDE, bot))
    pen.lineTo(p(W - LIP, bot))
    pen.lineTo(p(W - LIP, cy - h - REACH))
    # from the bottom, round the outer side, up to the top (angles: 0 = outer side)
    for c1, c2, end in arc(-W, ry, W, cy, -t0, t0, 4):
        pen.curveTo(p(*c1), p(*c2), p(*end))
    pen.closePath()


def glyph(mirror):
    tt = TTGlyphPen(None)
    corners(Cu2QuPen(tt, max_err=1, reverse_direction=False), mirror)
    return tt.glyph()


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "config", "fonts", "SupershellEnds.ttf")
    fb = FontBuilder(UPM, isTTF=True)
    names = [".notdef", "endLeft", "endRight"]
    fb.setupGlyphOrder(names)
    fb.setupCharacterMap({LEFT: "endLeft", RIGHT: "endRight"})
    empty = TTGlyphPen(None).glyph()
    fb.setupGlyf({".notdef": empty, "endLeft": glyph(False), "endRight": glyph(True)})
    # left side bearing = the outline's real left edge (the corners start at -SIDE).
    # TrueType places the outline by it: a 0 here would shift the whole end right by
    # SIDE, and the round would start inside its cell instead of at its left edge.
    glyf = fb.font["glyf"]
    lsb = {}
    for n in names:
        glyf[n].recalcBounds(glyf)
        lsb[n] = getattr(glyf[n], "xMin", 0)
    fb.setupHorizontalMetrics({n: (W, lsb[n]) for n in names})
    fb.setupHorizontalHeader(ascent=ASC, descent=-DESC)
    fb.setupNameTable({
        "familyName": "Supershell Ends",
        "styleName": "Regular",
        "uniqueFontIdentifier": "supershell-ends-1",
        "fullName": "Supershell Ends",
        "psName": "SupershellEnds-Regular",
        "version": "Version 1.000",
        "licenseDescription": "Drawn by scripts/gen-ends-font.py; same licence as supershell.",
    })
    fb.setupOS2(sTypoAscender=ASC, sTypoDescender=-DESC, sTypoLineGap=0,
                usWinAscent=ASC, usWinDescent=DESC, fsSelection=0x40 | 0x80,
                achVendID="SSHL", version=4)
    fb.font["OS/2"].panose.bProportion = 9          # monospaced
    fb.setupPost(isFixedPitch=1)
    fb.font["head"].created = fb.font["head"].modified = 0x0   # reproducible bytes
    os.makedirs(os.path.dirname(out), exist_ok=True)
    fb.save(out)
    print(out)


if __name__ == "__main__":
    main()
