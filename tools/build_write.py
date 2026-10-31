"""Fix pen coverage, order strokes and time them; write the animated logo SVG.
usage: build_write.py <render.png> <pen.json> <logo.svg> <out.svg> <coverage.png>"""
import json, math, re, sys
from collections import deque
from PIL import Image, ImageDraw

render, pen_path, logo_path, out_svg, cov_png = sys.argv[1:6]
R = 17                 # mask radius (stroke p95 radius 13.3 + margin)
SPEED = 2900           # px of pen travel per second
DOT_DUR = 0.12
DOT_PAUSE = 0.06

im = Image.open(render).convert("L"); W, H = im.size
inkpx = im.load()
pen = json.load(open(pen_path))
words = [[list(map(tuple, s)) for s in w["strokes"]] for w in pen["words"]]
word_tops = [w["top"] for w in pen["words"]]

def seglen(s): return sum(math.dist(s[i], s[i + 1]) for i in range(len(s) - 1))

def cover_mask(all_strokes, dots):
    m = Image.new("L", (W, H), 0); d = ImageDraw.Draw(m)
    for s in all_strokes:
        if len(s) > 1: d.line(s, fill=255, width=2 * R, joint="curve")
        for p in (s[0], s[-1]): d.ellipse([p[0] - R, p[1] - R, p[0] + R, p[1] + R], fill=255)
    for dot in dots:
        r = max(dot["w"], dot["h"]) / 2 + 3
        d.ellipse([dot["cx"] - r, dot["cy"] - r, dot["cx"] + r, dot["cy"] + r], fill=255)
    return m

def uncovered(all_strokes, dots):
    m = cover_mask(all_strokes, dots).load()
    return {(x, y) for y in range(H) for x in range(W) if inkpx[x, y] < 128 and m[x, y] < 128}

def blobs(points):
    pts, out = set(points), []
    while pts:
        p = pts.pop(); q, b = deque([p]), [p]
        while q:
            c = q.popleft()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (c[0] + dx, c[1] + dy)
                    if n in pts: pts.remove(n); q.append(n); b.append(n)
        out.append(b)
    return out

def line(a, b, step=3):
    n = max(1, int(math.dist(a, b) / step))
    return [(a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n) for i in range(n + 1)]

# --- 1. coverage fix-up: reach every uncovered tip ------------------------
for round_ in range(4):
    flat = [s for w in words for s in w]
    miss = uncovered(flat, pen["dots"])
    big = [b for b in blobs(miss) if len(b) >= 25]
    print(f"round {round_}: uncovered {len(miss)} px, {len(big)} blobs to reach")
    if not big: break
    for b in big:
        cx = sum(p[0] for p in b) / len(b); cy = sum(p[1] for p in b) / len(b)
        # nearest stroke point
        best = None
        for wi, w in enumerate(words):
            for si, s in enumerate(w):
                for pi, p in enumerate(s):
                    d = (p[0] - cx) ** 2 + (p[1] - cy) ** 2
                    if best is None or d < best[0]: best = (d, wi, si, pi)
        _, wi, si, pi = best
        s = words[wi][si]
        anchor = s[pi]
        tip = max(b, key=lambda p: (p[0] - anchor[0]) ** 2 + (p[1] - anchor[1]) ** 2)
        # stop short of the tip by most of the radius so the round cap ends at the ink's end
        dist = math.dist(anchor, tip)
        if dist < 2: continue
        reach = max(0.0, dist - R * 0.6)
        tipr = (anchor[0] + (tip[0] - anchor[0]) * reach / dist, anchor[1] + (tip[1] - anchor[1]) * reach / dist)
        out = line(anchor, tipr)
        if pi == 0:
            words[wi][si] = list(reversed(out))[:-1] + s           # start at the tip
        elif pi == len(s) - 1:
            words[wi][si] = s + out[1:]                            # end at the tip
        else:
            words[wi][si] = s[: pi + 1] + out[1:] + list(reversed(out))[1:-1] + s[pi:]  # out and back

flat = [s for w in words for s in w]
miss = uncovered(flat, pen["dots"])
total = sum(1 for v in im.getdata() if v < 128)
print(f"final: uncovered {len(miss)} of {total} px ({100 * len(miss) / total:.2f}%)")

# --- 2. time it as a left-to-right sweep per line, hard eased --------------
# The pen strokes are cut into short pieces, each drawn left to right; a
# piece draws while an imaginary sweep line, moving on a hard quint
# ease-in-out, crosses it. Top line first, then the bottom line.
LINE_TIME = [1.0, 1.15]      # seconds per line (Linn, Harrvik)
LINE_GAP = 0.08
PIECE = 26                   # px of pen path per piece
MIN_PIECE = 0.035            # s

def quint_in_out(t):
    t = min(1.0, max(0.0, t))
    return 16 * t ** 5 if t < 0.5 else 1 - (-2 * t + 2) ** 5 / 2

def quint_inverse(u):
    lo, hi = 0.0, 1.0
    for _ in range(40):
        m = (lo + hi) / 2
        if quint_in_out(m) < u: lo = m
        else: hi = m
    return (lo + hi) / 2

def pieces(s):
    out, cur, acc = [], [s[0]], 0.0
    for i in range(1, len(s)):
        acc += math.dist(s[i - 1], s[i]); cur.append(s[i])
        if acc >= PIECE:
            out.append(cur); cur, acc = [s[i]], 0.0
    if len(cur) > 1: out.append(cur)
    return out

dots_by_word = {i: [] for i in range(len(words))}
for dot in pen["dots"]:
    dists = [min(math.dist((dot["cx"], dot["cy"]), p) for s in w for p in s) for w in words]
    dots_by_word[dists.index(min(dists))].append(dot)

timeline, t0 = [], 0.0
for wi, w in enumerate(words):
    xs = [p[0] for s in w for p in s] + [d["cx"] for d in dots_by_word[wi]]
    x0, x1 = min(xs), max(xs)
    T = LINE_TIME[min(wi, len(LINE_TIME) - 1)]
    at = lambda x: t0 + T * quint_inverse((x - x0) / (x1 - x0))
    for s in w:
        for pc in pieces(s):
            if pc[0][0] > pc[-1][0]: pc = list(reversed(pc))
            a, b = min(p[0] for p in pc), max(p[0] for p in pc)
            start, stop = at(a), at(b)
            timeline.append((pc, start, max(MIN_PIECE, stop - start)))
    for dot in dots_by_word[wi]:
        a = (dot["cx"] - dot["w"] * 0.25, dot["cy"]); b = (dot["cx"] + dot["w"] * 0.25, dot["cy"])
        start = at(dot["cx"] - dot["w"] / 2)
        timeline.append(([a, b], start, max(MIN_PIECE, at(dot["cx"] + dot["w"] / 2) - start), max(dot["w"], dot["h"]) + 8))
    t0 += T + LINE_GAP

timeline.sort(key=lambda e: e[1])
total_time = max(e[1] + e[2] for e in timeline)
print(f"pieces: {len(timeline)}, total writing time {total_time:.2f}s")

# --- 3. write the SVG ------------------------------------------------------
logo = open(logo_path).read()
body = re.search(r"<svg[^>]*>(.*)</svg>", logo, re.S).group(1).strip()
def d_attr(pts):
    return "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in pts)
mask_paths = []
for entry in timeline:
    pts, delay, dur = entry[0], entry[1], entry[2]
    width = entry[3] if len(entry) > 3 else 2 * R
    mask_paths.append(
        f'<path class="pen" d="{d_attr(pts)}" pathLength="1" stroke-width="{width:.0f}" '
        f'style="--delay:{delay * 1000:.0f}ms;--dur:{dur * 1000:.0f}ms"/>'
    )
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" fill="none" data-write-duration="{total_time * 1000:.0f}">
<!-- Linn Harrvik signature, written in: the logo's own shapes are revealed by a
     mask of pen strokes traced along the letters, swept left to right per line
     on a hard ease (generated from linnlogo.svg). -->
<defs>
<mask id="linn-write" maskUnits="userSpaceOnUse" x="-40" y="-40" width="{W + 80}" height="{H + 80}">
<g fill="none" stroke="#fff" stroke-linecap="round" stroke-linejoin="round">
{chr(10).join(mask_paths)}
</g>
</mask>
</defs>
<g mask="url(#linn-write)">
{body}
</g>
</svg>
'''
open(out_svg, "w").write(svg)
print("wrote", out_svg, len(svg), "bytes")

# coverage picture for checking
dbg = Image.new("RGB", (W, H), "white")
dbg.paste((215, 215, 215), mask=im.point(lambda v: 255 if v < 128 else 0))
dr = ImageDraw.Draw(dbg)
for i, (s, delay, dur, *_) in enumerate(timeline):
    c = (int(230 * (1 - delay / total_time)), 60, int(230 * delay / total_time))
    dr.line(s, fill=c, width=3)
    dr.text((s[0][0] + 6, s[0][1] - 18), f"{delay:.2f}s", fill=c)
for (x, y) in miss: dbg.putpixel((x, y), (255, 0, 0))
dbg.save(cov_png)
