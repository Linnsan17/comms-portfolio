"""Check that pen strokes (with a given mask radius) cover every ink pixel.
usage: coverage.py <render.png> <pen.json> <radius> <out.png>"""
import json, math, sys
from PIL import Image, ImageDraw
src, pen_path, R, out = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]
im = Image.open(src).convert("L"); W, H = im.size
pen = json.load(open(pen_path))
mask = Image.new("L", (W, H), 0); d = ImageDraw.Draw(mask)
strokes = [s for w in pen["words"] for s in w["strokes"]]
for s in strokes:
    d.line([tuple(p) for p in s], fill=255, width=int(2 * R), joint="curve")
    for p in (s[0], s[-1]):
        d.ellipse([p[0] - R, p[1] - R, p[0] + R, p[1] + R], fill=255)
for dot in pen["dots"]:
    r = max(dot["w"], dot["h"]) / 2 + 2
    d.ellipse([dot["cx"] - r, dot["cy"] - r, dot["cx"] + r, dot["cy"] + r], fill=255)
ink = im.load(); m = mask.load()
missing = [(x, y) for y in range(H) for x in range(W) if ink[x, y] < 128 and m[x, y] < 128]
total = sum(1 for v in im.getdata() if v < 128)
print(f"radius {R}: uncovered ink {len(missing)} of {total} px ({100 * len(missing) / total:.2f}%)")
dbg = Image.new("RGB", (W, H), "white")
dbg.paste((220, 220, 220), mask=im.point(lambda v: 255 if v < 128 else 0))
dr = ImageDraw.Draw(dbg)
palette = [(230, 60, 60), (40, 120, 230), (40, 170, 90), (200, 120, 20), (150, 60, 200), (20, 160, 170), (220, 60, 160), (100, 100, 100), (160, 140, 0)]
for i, s in enumerate(strokes):
    c = palette[i % len(palette)]
    dr.line([tuple(p) for p in s], fill=c, width=3)
    dr.ellipse([s[0][0] - 7, s[0][1] - 7, s[0][0] + 7, s[0][1] + 7], fill=c)
    dr.text((s[0][0] + 9, s[0][1] - 20), f"{i + 1}", fill=c)
    # arrow-ish marker 40% along to show direction
    k = int(len(s) * 0.4); a, b = s[k], s[min(len(s) - 1, k + 6)]
    dr.line([tuple(a), tuple(b)], fill="black", width=6)
for (x, y) in missing:
    dbg.putpixel((x, y), (255, 0, 0))
dbg.save(out)
