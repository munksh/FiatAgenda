#!/usr/bin/env python3
"""
Fiat Agenda launcher icon.

THE SHAPE
---------
Sailfish icons are not rounded squares. The silhouette is a square in which
the inscribed circle replaces two diagonally opposite corners -- top-left and
bottom-right are arcs of radius side/2, top-right and bottom-left stay square.
Measured off the shipped Fiat Mos icon, which fits r = 86 on a 172 px side to
within a pixel.

Equivalently, and this is how it is drawn below:

    shape = inscribed circle  UNION  top-right quadrant  UNION  bottom-left quadrant

THE HOUSE LANGUAGE
------------------
    - the ground is the shape, in dark warm #1E1A12
    - a cream #F4EED8 field repeats the SAME shape, centred, 60.5% of the side
    - the instrument is drawn ON the cream in the ground colour
    - one small accent stroke, in the app's own colour

That last part is what the symbol matching the shape means: the mark does not
sit on the dark, it sits on a cream field cut to the same silhouette.

A consequence worth noting: the accent now has cream behind it rather than
near-black, so plum reads at about 5.5:1 instead of 2.6:1. The contrast worry
from the first version of this file is gone -- the shape fixed it.

THE MARK
--------
Fiat Mos is a tally cut into stone: four upright strokes and a fifth struck
across them. Agenda is a short list with the first line ticked -- Mos counts
what you did, Agenda crosses off what you owed.

A diagonal struck through the rules was tried first, to mirror Mos's fifth
stroke exactly. It reads as "not equal to", or as a smudge, and at 86 px it
reads as nothing at all. The tick had to sit BESIDE the line it ticks, not
across it.

Everything sits inside the inscribed circle -- radius 0.302 of the side from
the centre -- because the two arcs cut away exactly the corners a horizontal
list would otherwise run into. The furthest point below is at 0.233.

    python3 tools/make_icon.py           # writes icons/*/harbour-fiatagenda.png
    python3 tools/make_icon.py --sheet   # plus a contact sheet to look at
"""

import os
import sys

from PIL import Image, ImageDraw

GROUND = (0x1E, 0x1A, 0x12, 255)
CREAM  = (0xF4, 0xEE, 0xD8, 255)
ACCENT = (0x6E, 0x4A, 0x63, 255)      # the app's accent, plum

NAME  = "harbour-fiatagenda"
SIZES = [86, 108, 128, 172]
SS    = 4                              # supersample, then LANCZOS down

# Fractions of the icon's side.
FIELD  = 0.605                         # the cream field, centred
STROKE = 0.050

# The tick, two segments, in the accent.
TICK  = [(0.300, 0.470), (0.352, 0.525), (0.440, 0.400)]

# Three rules in the ground colour: x0, y, x1. The last one is short, because
# a list that stops mid-line reads as a list and a list of equal bars reads as
# a hamburger menu.
RULES = [(0.500, 0.410, 0.715),
         (0.500, 0.500, 0.715),
         (0.500, 0.590, 0.640)]


def shape_mask(n, box):
    """The Sailfish silhouette, as an 'L' mask of size n x n.

    box is (x0, y0, x1, y1) in pixels. Circle first, then the two square
    quadrants -- their union is the shape, and no subtraction is needed.
    """
    m = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(m)
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    d.ellipse([x0, y0, x1, y1], fill=255)          # the inscribed circle
    d.rectangle([cx, y0, x1, cy], fill=255)        # top-right stays square
    d.rectangle([x0, cy, cx, y1], fill=255)        # bottom-left stays square
    return m


def stroke(draw, pts, width, colour):
    """A line with round caps, the way the family draws."""
    draw.line(pts, fill=colour, width=int(round(width)), joint="curve")
    r = width / 2.0
    for x, y in (pts[0], pts[-1]):
        draw.ellipse([x - r, y - r, x + r, y + r], fill=colour)


def render(size):
    n = size * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))

    ground = Image.new("RGBA", (n, n), GROUND)
    img.paste(ground, (0, 0), shape_mask(n, (0, 0, n - 1, n - 1)))

    inset = (1.0 - FIELD) / 2.0
    fx0, fy0 = inset * n, inset * n
    fx1, fy1 = (1.0 - inset) * n - 1, (1.0 - inset) * n - 1
    field = Image.new("RGBA", (n, n), CREAM)
    img.paste(field, (0, 0), shape_mask(n, (fx0, fy0, fx1, fy1)))

    d = ImageDraw.Draw(img)
    w = n * STROKE
    stroke(d, [(x * n, y * n) for x, y in TICK], w, ACCENT)
    for x0, y, x1 in RULES:
        stroke(d, [(x0 * n, y * n), (x1 * n, y * n)], w, GROUND)

    return img.resize((size, size), Image.LANCZOS)


def hexof(c):
    return "#%02X%02X%02X" % c[:3]


def svg(side=172):
    """Same geometry, as a path. The silhouette is one arc, two lines, one arc."""
    s, r = float(side), side / 2.0
    w = side * STROKE
    inset = (1.0 - FIELD) / 2.0
    fx, fs = inset * side, FIELD * side
    fr = fs / 2.0

    outer = ("M%.2f,%.2f A%.2f,%.2f 0 0 0 %.2f,%.2f L%.2f,%.2f L%.2f,%.2f "
             "A%.2f,%.2f 0 0 0 %.2f,%.2f L%.2f,%.2f Z"
             % (r, 0, r, r, 0, r, 0, s, s - r, s, r, r, s, s - r, s, 0))
    inner = ("M%.2f,%.2f A%.2f,%.2f 0 0 0 %.2f,%.2f L%.2f,%.2f L%.2f,%.2f "
             "A%.2f,%.2f 0 0 0 %.2f,%.2f L%.2f,%.2f Z"
             % (fx + fr, fx, fr, fr, fx, fx + fr,
                fx, fx + fs, fx + fs - fr, fx + fs,
                fr, fr, fx + fs, fx + fs - fr, fx + fs, fx))

    rules = "\n".join(
        '  <path d="M%.2f,%.2f L%.2f,%.2f" stroke="%s" stroke-width="%.2f" '
        'stroke-linecap="round"/>' % (x0 * side, y * side, x1 * side, y * side,
                                      hexof(GROUND), w)
        for x0, y, x1 in RULES)

    tick = " ".join("%s%.2f,%.2f" % ("M" if i == 0 else "L", x * side, y * side)
                    for i, (x, y) in enumerate(TICK))

    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
            'viewBox="0 0 %d %d">\n'
            '  <path d="%s" fill="%s"/>\n'
            '  <path d="%s" fill="%s"/>\n'
            '  <path d="%s" stroke="%s" stroke-width="%.2f" stroke-linecap="round" '
            'stroke-linejoin="round" fill="none"/>\n'
            '%s\n</svg>\n'
            % (side, side, side, side,
               outer, hexof(GROUND), inner, hexof(CREAM),
               tick, hexof(ACCENT), w, rules))


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    for size in SIZES:
        folder = os.path.join(root, "icons", "%dx%d" % (size, size))
        os.makedirs(folder, exist_ok=True)
        path = os.path.join(folder, "%s.png" % NAME)
        render(size).save(path)
        print("wrote", os.path.relpath(path, root))

    src = os.path.join(root, "tools", "fiat-agenda-icon.svg")
    with open(src, "w") as fh:
        fh.write(svg())
    print("wrote", os.path.relpath(src, root))

    if "--sheet" in sys.argv:
        pad = 20
        sheet = Image.new("RGBA",
                          (sum(SIZES) + pad * (len(SIZES) + 1), max(SIZES) + pad * 2),
                          (40, 40, 40, 255))
        x = pad
        for size in SIZES:
            im = render(size)
            sheet.paste(im, (x, pad + (max(SIZES) - size) // 2), im)
            x += size + pad
        out = os.path.join(root, "tools", "icon-sheet.png")
        sheet.save(out)
        print("wrote", os.path.relpath(out, root))


if __name__ == "__main__":
    main()
