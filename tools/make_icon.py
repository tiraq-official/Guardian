#!/usr/bin/env python3
"""Generate Guardian's app icon (MD3-style rounded square + shield + check)."""
import os
from PIL import Image, ImageDraw, ImageFilter

S = 512
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "module")

TOP = (129, 96, 219)     # #8160DB
BOT = (74, 46, 158)      # #4A2E9E
CHECK = (73, 47, 158)

def bezier(p0, p1, p2, p3, n=24):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        x = u**3*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t**3*p3[0]
        y = u**3*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t**3*p3[1]
        pts.append((x, y))
    return pts

def shield_points():
    x0, W = 146, 220
    y0, H = 128, 240
    def m(sx, sy):
        return (x0 + (sx / 24.0) * W, y0 + ((sy - 1) / 22.0) * H)
    pts = [m(12, 1), m(3, 5), m(3, 11)]
    # left curved side down to the point
    pts += bezier(m(3, 11), m(3, 16.5), m(6.8, 21.7), m(12, 23))
    # right curved side back up
    pts += bezier(m(12, 23), m(17.2, 21.7), m(21, 16.5), m(21, 11))
    pts += [m(21, 5)]
    return pts

def gradient(size):
    g = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(g)
    for y in range(size):
        t = y / (size - 1)
        c = tuple(int(TOP[i] + (BOT[i] - TOP[i]) * t) for i in range(3))
        d.line([(0, y), (size, y)], fill=c)
    return g

def build(size):
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    sq = Image.new("L", (S, S), 0)
    ImageDraw.Draw(sq).rounded_rectangle([0, 0, S - 1, S - 1], radius=118, fill=255)
    canvas.paste(gradient(S), (0, 0), sq)

    sh = Image.new("L", (S, S), 0)
    ImageDraw.Draw(sh).polygon(shield_points(), fill=255)
    sh = sh.filter(ImageFilter.GaussianBlur(2.2)).point(lambda p: 255 if p > 128 else 0)
    canvas.paste(Image.new("RGBA", (S, S), (255, 255, 255, 255)), (0, 0), sh)

    ck = Image.new("L", (S, S), 0)
    dc = ImageDraw.Draw(ck)
    a, b, c = (212, 262), (244, 292), (304, 216)
    dc.line([a, b, c], fill=255, width=26, joint="curve")
    for p in (a, b, c):
        dc.ellipse([p[0] - 13, p[1] - 13, p[0] + 13, p[1] + 13], fill=255)
    ck = ck.filter(ImageFilter.GaussianBlur(1.4)).point(lambda p: 255 if p > 128 else 0)
    canvas.paste(Image.new("RGBA", (S, S), CHECK + (255,)), (0, 0), ck)

    return canvas.resize((size, size), Image.LANCZOS)

def main():
    big = build(512)
    big.save(os.path.join(OUT, "icon.png"))
    big.save(os.path.join(OUT, "webroot", "icon.png"))
    print("wrote module/icon.png and module/webroot/icon.png")

if __name__ == "__main__":
    main()
