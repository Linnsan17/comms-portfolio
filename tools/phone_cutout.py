"""Cut the hand and phone out of the hero photo for the front hero card.

usage: python3 phone_cutout.py <photo.png> <photo-mask.png> <out.webp>

<photo-mask.png> comes from tools/lift.swift (macOS Vision subject lift).
The photo's background is a purely vertical gradient, so each row's colour
is known: pixels that match it are dropped (the gap between thumb and
phone), and edge pixels have the background's share taken back out, so no
pink fringe is left. Prints the screen's corners inside the bezel, as
fractions of the cut-out, for PHONE_SCREEN in main.js.
"""
import sys
from PIL import Image

src, mask_path, out = sys.argv[1:4]
im = Image.open(src).convert("RGB")
w, h = im.size
px = im.load()
mk = Image.open(mask_path).convert("L").resize((w, h)).load()

bg = []
for y in range(h):
    row = sorted(px[x, y] for x in range(0, 600, 3))
    bg.append(row[len(row) // 2])

cut = Image.new("RGBA", (w, h))
cp = cut.load()
for y in range(h):
    B = bg[y]
    for x in range(w):
        av = mk[x, y] / 255
        if av <= 0:
            continue
        C = px[x, y]
        dist = sum((C[k] - B[k]) ** 2 for k in range(3)) ** 0.5
        a = min(av, min(1, max(0, (dist - 10) / 45)))
        if a < 0.02:
            continue
        F = tuple(int(min(255, max(0, (C[k] - (1 - a) * B[k]) / a))) for k in range(3))
        cp[x, y] = F + (round(a * 255),)
box = cut.getchannel("A").getbbox()
cut = cut.crop(box)

# The blacked-out screen is one flat fill: trace it, fit a line to each
# edge, and meet them for the corners of the phone's face
fill = lambda c: abs(c[0] - 4) <= 3 and abs(c[1] - 3) <= 2 and abs(c[2] - 3) <= 3
seen, stack, face = set(), [(w // 2 - 40, h // 2)], set()
while stack:
    x, y = stack.pop()
    if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
        continue
    seen.add((x, y))
    if fill(px[x, y]):
        face.add((x, y))
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
rows, cols = {}, {}
for x, y in face:
    r = rows.setdefault(y, [x, x]); r[0] = min(r[0], x); r[1] = max(r[1], x)
    c = cols.setdefault(x, [y, y]); c[0] = min(c[0], y); c[1] = max(c[1], y)


def fit(pts):
    for _ in range(2):
        n = len(pts)
        su = sum(p[0] for p in pts); sv = sum(p[1] for p in pts)
        suu = sum(p[0] ** 2 for p in pts); suv = sum(p[0] * p[1] for p in pts)
        a = (n * suv - su * sv) / (n * suu - su * su)
        b = (sv - a * su) / n
        pts = [p for p in pts if abs(p[1] - (a * p[0] + b)) < 2.5]
    return a, b


ys, xs = sorted(rows), sorted(cols)
my, mx = (ys[-1] - ys[0]) * 0.15, (xs[-1] - xs[0]) * 0.2
inner_y = [y for y in ys if ys[0] + my < y < ys[-1] - my]
inner_x = [x for x in xs if xs[0] + mx < x < xs[-1] - mx]
left = fit([(y, rows[y][0]) for y in inner_y])
right = fit([(y, rows[y][1]) for y in inner_y])
top = fit([(x, cols[x][0]) for x in inner_x])
bottom = fit([(x, cols[x][1]) for x in inner_x])


def meet(v, hz):
    y = (hz[0] * v[1] + hz[1]) / (1 - hz[0] * v[0])
    return v[0] * y + v[1] - box[0], y - box[1]


P = [meet(left, top), meet(right, top), meet(right, bottom), meet(left, bottom)]


def warp(P):
    (x0, y0), (x1, y1), (x2, y2), (x3, y3) = P
    dx1, dx2, dx3 = x1 - x2, x3 - x2, x0 - x1 + x2 - x3
    dy1, dy2, dy3 = y1 - y2, y3 - y2, y0 - y1 + y2 - y3
    den = dx1 * dy2 - dx2 * dy1
    g = (dx3 * dy2 - dx2 * dy3) / den
    k = (dx1 * dy3 - dx3 * dy1) / den
    a, b = x1 - x0 + g * x1, x3 - x0 + k * x3
    d, e = y1 - y0 + g * y1, y3 - y0 + k * y3
    return lambda u, v: ((a * u + b * v + x0) / (g * u + k * v + 1), (d * u + e * v + y0) / (g * u + k * v + 1))


onto = warp(P)
bx = 0.032  # bezel, as a share of the face's width
by = bx * 0.487  # on a phone face 0.487 as wide as it is tall
cw, ch = cut.size
screen = [onto(u, v) for u, v in ((bx, by), (1 - bx, by), (1 - bx, 1 - by), (bx, 1 - by))]
print("PHONE_SCREEN =", [[round(x / cw, 5), round(y / ch, 5)] for x, y in screen])

web = cut.resize((760, round(760 * ch / cw)), Image.LANCZOS)
web.save(out, "WEBP", quality=90, method=6)
print("saved", out, web.size)
