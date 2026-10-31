"""Trace a handwriting pen path through the filled Linn Harrvik logo.

usage: skeleton.py <render.png> <out.json> <debug.png>
"""
import json, math, sys
from collections import deque
from PIL import Image, ImageDraw

src, out_json, debug_png = sys.argv[1:4]
im = Image.open(src).convert("L")
W, H = im.size
px = im.load()
ink = {(x, y) for y in range(H) for x in range(W) if px[x, y] < 128}

N8 = [(-1, -1), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0)]

# --- connected components ------------------------------------------------
comps, seen = [], set()
for p in ink:
    if p in seen: continue
    q, comp = deque([p]), []
    seen.add(p)
    while q:
        c = q.popleft(); comp.append(c)
        for dx, dy in N8:
            n = (c[0] + dx, c[1] + dy)
            if n in ink and n not in seen:
                seen.add(n); q.append(n)
    comps.append(comp)
comps.sort(key=len, reverse=True)
print("components:", [len(c) for c in comps[:8]])

# --- distance to background (chamfer 3/4, in px*3) -------------------------
INF = 10 ** 9
dist = {p: INF for p in ink}
for y in range(H):
    for x in range(W):
        if (x, y) not in ink: continue
        best = dist[(x, y)]
        for dx, dy, c in ((-1, 0, 3), (0, -1, 3), (-1, -1, 4), (1, -1, 4)):
            n = (x + dx, y + dy)
            best = min(best, (dist[n] if n in ink else 0) + c)
        dist[(x, y)] = best
for y in range(H - 1, -1, -1):
    for x in range(W - 1, -1, -1):
        if (x, y) not in ink: continue
        best = dist[(x, y)]
        for dx, dy, c in ((1, 0, 3), (0, 1, 3), (1, 1, 4), (-1, 1, 4)):
            n = (x + dx, y + dy)
            best = min(best, (dist[n] if n in ink else 0) + c)
        dist[(x, y)] = best

# --- Zhang-Suen thinning ---------------------------------------------------
def thin(pixels):
    s = set(pixels)
    order = [(0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)]  # P2..P9
    changed = True
    while changed:
        changed = False
        for step in (0, 1):
            remove = []
            for (x, y) in s:
                nb = [((x + dx, y + dy) in s) for dx, dy in order]
                b = sum(nb)
                if b < 2 or b > 6: continue
                a = sum(1 for i in range(8) if not nb[i] and nb[(i + 1) % 8])
                if a != 1: continue
                p2, p4, p6, p8 = nb[0], nb[2], nb[4], nb[6]
                if step == 0:
                    if p2 and p4 and p6: continue
                    if p4 and p6 and p8: continue
                else:
                    if p2 and p4 and p8: continue
                    if p2 and p6 and p8: continue
                remove.append((x, y))
            if remove:
                changed = True
                s.difference_update(remove)
    return s

def neighbours(p, s):
    return [(p[0] + dx, p[1] + dy) for dx, dy in N8 if (p[0] + dx, p[1] + dy) in s]

# --- skeleton graph: nodes = endpoints and junction clusters, edges = runs --
def build_graph(skel):
    deg = {p: len(neighbours(p, skel)) for p in skel}
    special = {p for p in skel if deg[p] != 2}
    # cluster adjacent junction pixels into one node
    node_of, nodes = {}, []
    for p in special:
        if p in node_of: continue
        q, cl = deque([p]), []
        node_of[p] = len(nodes)
        while q:
            c = q.popleft(); cl.append(c)
            for n in neighbours(c, skel):
                if n in special and n not in node_of:
                    node_of[n] = len(nodes); q.append(n)
        nodes.append(cl)
    edges, used = [], set()
    for ni, cl in enumerate(nodes):
        for start in cl:
            for n in neighbours(start, skel):
                if n in special or (start, n) in used: continue
                path, prev, cur = [start, n], start, n
                used.add((start, n))
                while cur not in special:
                    nxt = [m for m in neighbours(cur, skel) if m != prev and m not in path[-3:]]
                    if not nxt: break
                    # prefer the special pixel if adjacent, else the first
                    nxt.sort(key=lambda m: (m not in special, abs(m[0] - cur[0]) + abs(m[1] - cur[1])))
                    prev, cur = cur, nxt[0]
                    path.append(cur)
                if cur in special:
                    used.add((cur, prev))
                    edges.append({"a": ni, "b": node_of[cur], "pts": path})
                else:
                    edges.append({"a": ni, "b": None, "pts": path})
    # pure loops with no special pixel
    return nodes, edges

def length(pts):
    return sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))

def direction(pts, k=10):
    a, b = pts[0], pts[min(k, len(pts) - 1)]
    d = math.hypot(b[0] - a[0], b[1] - a[1]) or 1
    return ((b[0] - a[0]) / d, (b[1] - a[1]) / d)

def plan(nodes, edges):
    centre = {i: (sum(p[0] for p in cl) / len(cl), sum(p[1] for p in cl) / len(cl)) for i, cl in enumerate(nodes)}
    # merge nodes closer than 7px (thinning leaves junctions as near-twins)
    parent = list(range(len(nodes)))
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]; i = parent[i]
        return i
    for e in edges:
        if e["b"] is not None and e["a"] != e["b"] and length(e["pts"]) < 7:
            parent[find(e["a"])] = find(e["b"])
    E = []
    for e in edges:
        if e["b"] is None: continue
        a, b = find(e["a"]), find(e["b"])
        if a == b and length(e["pts"]) < 7: continue
        E.append({"a": a, "b": b, "pts": e["pts"]})
    # drop tiny dead-end spurs (outline bumps), not real strokes
    for _ in range(2):
        deg = {}
        for e in E:
            deg[e["a"]] = deg.get(e["a"], 0) + 1
            deg[e["b"]] = deg.get(e["b"], 0) + 1
        E = [e for e in E if not ((deg[e["a"]] == 1 or deg[e["b"]] == 1) and deg[e["a"]] + deg[e["b"]] > 2 and length(e["pts"]) < 18)]
    at = {}
    for i, e in enumerate(E):
        at.setdefault(e["a"], []).append(i)
        if e["b"] != e["a"]: at.setdefault(e["b"], []).append(i)
    pos = {n: centre.get(n, E[at[n][0]]["pts"][0]) for n in at}

    def orient(i, node):
        e = E[i]
        return e["pts"] if e["a"] == node else list(reversed(e["pts"]))

    def dot(u, v): return u[0] * v[0] + u[1] * v[1]

    MAX_RETRACE = 90
    done, strokes = set(), []
    while len(done) < len(E):
        cands = [n for n in at if any(i not in done for i in at[n])]
        ends = [n for n in cands if len(at[n]) == 1]
        pool = ends or cands
        if strokes:
            last = strokes[-1][-1]
            node = min(pool, key=lambda n: math.dist(pos[n], last))
        else:
            node = min(pool, key=lambda n: pos[n][0])
        path, stack, heading = [], [], None
        while True:
            options = [i for i in at.get(node, []) if i not in done]
            if options:
                if heading is None:
                    i = max(options, key=lambda i: length(E[i]["pts"]))
                else:
                    i = max(options, key=lambda i: dot(direction(orient(i, node), 14), heading))
                done.add(i)
                pts = orient(i, node)
                path.extend(pts if not path else pts[1:])
                stack.append((node, pts))
                e = E[i]
                node = e["b"] if e["a"] == node else e["a"]
                tail = list(reversed(path[-15:]))
                d = direction(tail, 14)
                heading = (-d[0], -d[1])
                continue
            # dead end: retrace back to the nearest node with work left, if close
            retrace, back = [], len(stack) - 1
            while back >= 0:
                n_back, pts = stack[back]
                retrace.extend(list(reversed(pts))[1:])
                if any(i not in done for i in at.get(n_back, [])): break
                back -= 1
            if back < 0 or length([path[-1]] + retrace) > MAX_RETRACE:
                break
            path.extend(retrace)
            node = stack[back][0]
            del stack[back:]
            tail = list(reversed(path[-15:]))
            d = direction(tail, 14)
            heading = (-d[0], -d[1])
        if len(path) > 1: strokes.append(path)
    return strokes

def rdp(pts, eps):
    if len(pts) < 3: return pts
    a, b = pts[0], pts[-1]
    dx, dy = b[0] - a[0], b[1] - a[1]
    norm = math.hypot(dx, dy) or 1
    i_max, d_max = 0, -1
    for i in range(1, len(pts) - 1):
        d = abs(dy * (pts[i][0] - a[0]) - dx * (pts[i][1] - a[1])) / norm
        if d > d_max: i_max, d_max = i, d
    if d_max <= eps: return [a, b]
    return rdp(pts[: i_max + 1], eps)[:-1] + rdp(pts[i_max:], eps)

def chaikin(pts, n=2):
    for _ in range(n):
        out = [pts[0]]
        for i in range(len(pts) - 1):
            p, q = pts[i], pts[i + 1]
            out += [(0.75 * p[0] + 0.25 * q[0], 0.75 * p[1] + 0.25 * q[1]), (0.25 * p[0] + 0.75 * q[0], 0.25 * p[1] + 0.75 * q[1])]
        out.append(pts[-1])
        pts = out
    return pts

result = {"width": W, "height": H, "words": []}
big = [c for c in comps if len(c) > 2000]
dots = [c for c in comps if 150 < len(c) <= 2000]
print("big strokes:", len(big), "dots:", len(dots))
radii = []
for comp in big:
    skel = thin(comp)
    radii += [dist[p] / 3 for p in skel]
    nodes, edges = build_graph(skel)
    strokes = plan(nodes, edges)
    smooth = [chaikin(rdp(s, 0.9), 2) for s in strokes]
    ys = [p[1] for p in comp]
    result["words"].append({"top": min(ys), "strokes": [[(round(x, 1), round(y, 1)) for x, y in s] for s in smooth]})
    print(f"component {len(comp)} px: {len(nodes)} nodes, {len(edges)} edges -> {len(strokes)} strokes, lengths {[round(length(s)) for s in smooth]}")
result["words"].sort(key=lambda w: w["top"])
dot_marks = []
for d in dots:
    xs = [p[0] for p in d]; ys = [p[1] for p in d]
    dot_marks.append({"cx": (min(xs) + max(xs)) / 2, "cy": (min(ys) + max(ys)) / 2, "w": max(xs) - min(xs) + 1, "h": max(ys) - min(ys) + 1})
result["dots"] = dot_marks
radii.sort()
result["stroke_radius_p50"] = radii[len(radii) // 2]
result["stroke_radius_p95"] = radii[int(len(radii) * 0.95)]
print("stroke radius p50 %.1f p95 %.1f" % (result["stroke_radius_p50"], result["stroke_radius_p95"]))
json.dump(result, open(out_json, "w"))

# debug: draw strokes in writing order over a faint logo
dbg = Image.new("RGB", (W, H), "white")
faint = Image.new("RGB", (W, H), (225, 225, 225))
dbg.paste(faint, mask=im.point(lambda v: 255 if v < 128 else 0))
dr = ImageDraw.Draw(dbg)
all_strokes = [s for w in result["words"] for s in w["strokes"]]
total = sum(len(s) for s in all_strokes)
k = 0
import colorsys
for si, s in enumerate(all_strokes):
    for i in range(len(s) - 1):
        r, g, b = colorsys.hsv_to_rgb(0.75 * k / total, 1, 0.85)
        dr.line([s[i], s[i + 1]], fill=(int(r * 255), int(g * 255), int(b * 255)), width=3)
        k += 1
    dr.ellipse([s[0][0] - 6, s[0][1] - 6, s[0][0] + 6, s[0][1] + 6], outline="black", width=2)
    dr.text((s[0][0] + 8, s[0][1] - 18), str(si + 1), fill="black")
for d in dot_marks:
    dr.ellipse([d["cx"] - 5, d["cy"] - 5, d["cx"] + 5, d["cy"] + 5], fill="black")
dbg.save(debug_png)
