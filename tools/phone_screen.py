"""phone_screen.py <track.txt> <screen.txt>

The screen of the phone that phone_track.swift followed, in every frame.
The phone in Svedea's reel only tips towards and away from the camera, so
each frame shows it as a symmetric trapezoid. Each frame's pose (where the
phone is and how far it tips) is solved against its outline with a pinhole
camera. The phone has depth: tipped, one of its ends shows, so the outline's
top or bottom there is the back of the phone, not its face. The camera's
focal length and the phone's depth are fitted once, on the frames where the
whole phone shows. The screen is then the phone's face inset by its bezel,
as measured on the front-facing frame at 10 s (an iPhone 15 Pro: 340 x 705 px,
the screen 315 x 684 inside it).

screen.txt: frame, then the screen's corners (top left, top right, bottom
right, bottom left) as x,y in the reel's pixels from the top left.
"""
import math
import sys

CX, CY = 960.0, 540.0
W = 1.0
H = 705 / 340  # the phone's height in widths
INSET_X = 12.5 / 340  # each side, as a share of the width
INSET_TOP, INSET_BOTTOM = 10 / 705, 11 / 705  # as shares of the height

frames = {}
for line in open(sys.argv[1]):
    if line.startswith("#") or "none" in line:
        continue
    head, *sides = line.split("|")
    parse = lambda s: None if s.strip() == "-" else tuple(map(float, s.split(",")))
    L, R, T, B = (parse(s) for s in sides)
    if L and R and (T or B):
        frames[int(head.split()[0])] = (L, R, T, B)


def corners(p, f, t):
    """the face's and the back's corners in the image, for pose p = (x, y, z, tilt)"""
    xc, yc, zc, th = p
    s, c = math.sin(th), math.cos(th)
    face, back = [], []
    for du, dv in ((-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)):
        P = (xc + du * W, yc + dv * H * c, zc + dv * H * s)
        Q = (P[0], P[1] - t * s, P[2] + t * c)  # the back, away from the camera
        face.append((CX + f * P[0] / P[2], CY + f * P[1] / P[2]))
        back.append((CX + f * Q[0] / Q[2], CY + f * Q[1] / Q[2]))
    return face, back


def x_on(a, b, y):
    # x where the line through a and b crosses row y
    return a[0] + (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1])


def residuals(p, meas, f, t):
    L, R, T, B, rows = meas
    face, back = corners(p, f, t)
    res = []
    for y in rows:
        res.append(x_on(face[0], face[3], y) - (L[0] * y + L[1]))
        res.append(x_on(face[1], face[2], y) - (R[0] * y + R[1]))
    if T:
        res.append(min(face[0][1], back[0][1]) - T[1])
    if B:
        res.append(max(face[3][1], back[3][1]) - B[1])
    return res


def solve(meas, f, t, p):
    """Levenberg-Marquardt on the four pose numbers"""
    lam = 1e-3
    cost = sum(r * r for r in residuals(p, meas, f, t))
    steps = (0.002, 0.002, 0.01, 0.0005)
    for _ in range(40):
        r0 = residuals(p, meas, f, t)
        J = []
        for i, h in enumerate(steps):
            q = list(p)
            q[i] += h
            J.append([(a - b) / h for a, b in zip(residuals(q, meas, f, t), r0)])
        # normal equations (J^T J + lam diag) dp = -J^T r
        A = [[sum(J[i][k] * J[j][k] for k in range(len(r0))) for j in range(4)] for i in range(4)]
        g = [-sum(J[i][k] * r0[k] for k in range(len(r0))) for i in range(4)]
        for i in range(4):
            A[i][i] *= 1 + lam
        M = [row[:] + [g[i]] for i, row in enumerate(A)]
        for col in range(4):
            piv = max(range(col, 4), key=lambda r: abs(M[r][col]))
            M[col], M[piv] = M[piv], M[col]
            if abs(M[col][col]) < 1e-12:
                return p, cost
            for r in range(4):
                if r != col:
                    k = M[r][col] / M[col][col]
                    M[r] = [a - k * b for a, b in zip(M[r], M[col])]
        dp = [M[i][4] / M[i][i] for i in range(4)]
        q = [a + b for a, b in zip(p, dp)]
        new = sum(r * r for r in residuals(q, meas, f, t))
        if new < cost:
            p, cost, lam = q, new, lam * 0.3
            if max(abs(d) for d in dp) < 1e-7:
                break
        else:
            lam *= 10
    return p, cost


def measurements(L, R, T, B):
    top = T[1] if T else 0
    bottom = B[1] if B else 1079
    span = bottom - top
    return (L, R, T, B, (top + span * 0.3, bottom - span * 0.3))


def first_guess(L, R, T, B, f):
    y = T[1] if T else B[1]
    w = (R[0] * y + R[1]) - (L[0] * y + L[1])
    z = f / w
    da = L[0] - R[0]
    th = 0.0 if abs(da) < 1e-6 else math.atan2(f, (R[1] - L[1]) / da - CY)
    if th > math.pi / 2:
        th -= math.pi
    yc = (y - CY) * z / f + (H / 2 if T else -H / 2) * math.cos(th)
    xc = (((R[0] + L[0]) * y + R[1] + L[1]) / 2 - CX) * z / f
    return [xc, yc, z + (H / 2 if T else -H / 2) * math.sin(th), th]


# the focal length and the phone's depth, fitted on frames where it all shows
full = [k for k, (L, R, T, B) in frames.items() if T and B][::8]
best = None
for f in range(1000, 4001, 100):
    for t10 in range(4, 17, 2):
        t = t10 / 100
        total = 0
        for k in full:
            L, R, T, B = frames[k]
            m = measurements(L, R, T, B)
            total += solve(m, f, t, first_guess(L, R, T, B, f))[1]
        if best is None or total < best[0]:
            best = (total, f, t)
_, F, TH = best
print(f"focal length {F} px, depth {TH} widths; rms {math.sqrt(best[0] / len(full) / 6):.2f} px", file=sys.stderr)

out = open(sys.argv[2], "w")
out.write("# frame | screen corners top left, top right, bottom right, bottom left (x,y)\n")
worst = 0
for k in sorted(frames):
    L, R, T, B = frames[k]
    m = measurements(L, R, T, B)
    p, cost = solve(m, F, TH, first_guess(L, R, T, B, F))
    worst = max(worst, math.sqrt(cost / len(residuals(p, m, F, TH))))
    face, _ = corners(p, F, TH)
    # the screen: the face inset by the bezel (in the face's own plane)
    xc, yc, zc, th = p
    s, c = math.sin(th), math.cos(th)
    u = W / 2 * (1 - 2 * INSET_X)
    pts = []
    for du, dv in ((-u, -H / 2 * (1 - 2 * INSET_TOP)), (u, -H / 2 * (1 - 2 * INSET_TOP)), (u, H / 2 * (1 - 2 * INSET_BOTTOM)), (-u, H / 2 * (1 - 2 * INSET_BOTTOM))):
        P = (xc + du, yc + dv * c, zc + dv * s)
        pts.append((CX + F * P[0] / P[2], CY + F * P[1] / P[2]))
    out.write(f"{k} " + " ".join(f"{x:.2f},{y:.2f}" for x, y in pts) + "\n")
print("worst frame rms", round(worst, 2), "px; wrote", sys.argv[2], file=sys.stderr)
