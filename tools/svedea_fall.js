// The falling stories in Svedea's case film, worked out with Matter.js.
//
// Five cards (186 px wide, the stories' own shape) drop one after another
// onto the floor of the 896x752 card: four land upright with a wobble, the
// snowmobile post lands across two of them. After a hold the floor goes and
// they drop out the bottom, as the pet photos do in Svedea's reel. 406 frames
// at 60 fps, the length of the reel's pet-photo shot (22.0167-28.775 s).
//
// To run it again: open any page in a browser, load
// https://cdn.jsdelivr.net/npm/matter-js@0.20.0/build/matter.min.js, paste
// this file into the console, then copy(svedeaFall()) and paste the text into
// fall.txt (next to the story images) for svedea_edit.swift.

function svedeaFall() {
  const { Engine, Bodies, Composite, Body } = Matter;
  const W = 896, H = 752, FRAMES = 406, DROP = 362;
  // which story (0-4: helmet, det ena, hojsemester, musik, snowmobile post),
  // the frame it drops in, where, its tilt and spin; the post lies across
  const plan = [
    { i: 0, f: 2, x: 114, a: -0.04, s: 0.0015 },
    { i: 2, f: 12, x: 562, a: 0.05, s: -0.002 },
    { i: 1, f: 22, x: 338, a: 0.03, s: 0.001 },
    { i: 3, f: 32, x: 782, a: -0.05, s: -0.0015 },
    { i: 4, f: 50, x: 450, a: 1.5, s: 0.004, k: 2 },
  ];
  const engine = Engine.create({ positionIterations: 30, velocityIterations: 24 });
  engine.gravity.y = 1.6;
  const ground = Bodies.rectangle(W / 2, H + 100, W * 3, 200, { isStatic: true, friction: 1 });
  const walls = [-100, W + 100].map((x) => Bodies.rectangle(x, H / 2 - 400, 200, H * 3, { isStatic: true, friction: 0.2 }));
  Composite.add(engine.world, [ground, ...walls]);
  const cw = 186;
  const hs = [2140, 2140, 2140, 2140, 2044].map((h) => (cw * h) / 1206);
  const bodies = [];
  const lines = [];
  for (let f = 0; f < FRAMES; f++) {
    for (const p of plan) {
      if (p.f !== f) continue;
      const b = Bodies.rectangle(p.x, -hs[p.i] / 2 - 20, cw, hs[p.i], {
        angle: p.a, chamfer: { radius: 6 }, restitution: 0, friction: 0.9, frictionStatic: 2, frictionAir: 0.01, density: 0.002,
      });
      // heavier to turn, so the tall cards land upright instead of toppling
      Body.setInertia(b, b.inertia * (p.k ?? 5));
      Body.setVelocity(b, { x: 0, y: 3 });
      Body.setAngularVelocity(b, p.s);
      bodies[p.i] = b;
      Composite.add(engine.world, b);
    }
    // the floor goes, and a push sends the pile out before the reel cuts
    if (f === DROP) {
      Composite.remove(engine.world, ground);
      bodies.forEach((b) => Body.setVelocity(b, { x: b.velocity.x, y: 8 }));
    }
    Engine.update(engine, 1000 / 60);
    lines.push(
      [0, 1, 2, 3, 4]
        .map((i) => (bodies[i] ? [bodies[i].position.x.toFixed(2), bodies[i].position.y.toFixed(2), bodies[i].angle.toFixed(4)].join(",") : "-"))
        .join(" ")
    );
  }
  const header = "# svedea stories fall: 896x752 card, 60 fps, 406 frames from 22.0167 s; per frame 5 cards (helmet, det ena, hojsemester, musik, snoskoter post) as x,y,angle of the centre, or - before it drops in; card 186 wide";
  return header + "\n" + lines.join("\n") + "\n";
}
