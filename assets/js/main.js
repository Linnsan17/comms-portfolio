// Filter the case list by discipline. The active filter lives in the URL
// (?tag=social) so the capability links and shared links open pre-filtered.

const chips = document.querySelectorAll("[data-filter]");
const cards = document.querySelectorAll("[data-tags]");
const empty = document.querySelector("[data-empty]");

function applyFilter(tag) {
  let shown = 0;

  cards.forEach((card) => {
    const tags = card.dataset.tags.split(" ").filter(Boolean);
    const match = tag === "all" || tags.includes(tag);
    card.hidden = !match;
    if (match) shown += 1;
  });

  chips.forEach((chip) => {
    chip.setAttribute("aria-pressed", String(chip.dataset.filter === tag));
  });

  if (empty) empty.hidden = shown > 0;
}

if (chips.length) {
  const known = [...chips].map((chip) => chip.dataset.filter);
  const fromUrl = new URLSearchParams(location.search).get("tag");
  applyFilter(known.includes(fromUrl) ? fromUrl : "all");

  chips.forEach((chip) => {
    chip.addEventListener("click", () => {
      const tag = chip.dataset.filter;
      applyFilter(tag);
      const url = new URL(location.href);
      if (tag === "all") url.searchParams.delete("tag");
      else url.searchParams.set("tag", tag);
      history.replaceState(null, "", url);
    });
  });
}

document.querySelectorAll("[data-year]").forEach((el) => {
  el.textContent = new Date().getFullYear();
});

const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;

// Smooth scroll. Measured from serious.business: the page eases to a stop
// by ~10% of the remaining distance per frame, which is Lenis' default lerp.
const lenis =
  window.Lenis && !reduceMotion ? new Lenis({ lerp: 0.1, anchors: true }) : null;

// Stacked service cards. Each card scrolls normally until its top reaches
// STACK_LINE of the viewport, then moves at STACK_SPEED of the page so the
// next card slides over it. That stops once the last card reaches the line,
// and the whole stack scrolls away together. Values measured frame by frame.
const STACK_LINE = 0.27;
const STACK_SPEED = 0.436;

const stackCards = reduceMotion ? [] : [...document.querySelectorAll("[data-stack] [data-card]")];
let naturalTops = [];

function measureStack() {
  stackCards.forEach((card) => (card.style.transform = ""));
  naturalTops = stackCards.map((card) => card.getBoundingClientRect().top + scrollY);
}

function updateStack() {
  if (stackCards.length < 2) return;
  const line = innerHeight * STACK_LINE;
  const lastTop = naturalTops[naturalTops.length - 1];

  stackCards.forEach((card, i) => {
    if (i === stackCards.length - 1) return;
    const top = naturalTops[i] - scrollY;
    const past = Math.min(Math.max(line - top, 0), lastTop - naturalTops[i]);
    card.style.transform = past ? `translate3d(0, ${past * (1 - STACK_SPEED)}px, 0)` : "";
  });
}

// Line reveal: split text into lines, each in its own mask, and slide them
// up with a 60ms stagger when the block is 90% of the way up the viewport.
const revealBlocks = [...document.querySelectorAll("[data-reveal]")];

function wrapLine(content, index) {
  const mask = document.createElement("span");
  const inner = document.createElement("span");
  mask.className = "line";
  inner.className = "line__inner";
  inner.style.setProperty("--i", index);
  inner.append(content);
  mask.append(inner);
  return mask;
}

function splitParagraph(el) {
  const text = (el.dataset.text ??= el.textContent.trim().replace(/\s+/g, " "));
  el.textContent = "";
  const words = text.split(" ").map((word) => {
    const span = document.createElement("span");
    span.textContent = word;
    el.append(span, " ");
    return span;
  });

  const lines = [];
  let lastTop = null;
  words.forEach((word) => {
    if (word.offsetTop !== lastTop) {
      lastTop = word.offsetTop;
      lines.push([]);
    }
    lines[lines.length - 1].push(word.textContent);
  });

  el.textContent = "";
  lines.forEach((line, i) => el.append(wrapLine(line.join(" "), i)));
}

function splitBlock(block) {
  block.querySelectorAll("[data-lines]").forEach(splitParagraph);
  block.querySelectorAll("li").forEach((item, i) => {
    const text = (item.dataset.text ??= item.textContent.trim());
    item.textContent = "";
    item.append(wrapLine(text, i));
  });
  block.classList.add("is-split");
}

if (revealBlocks.length) {
  if (reduceMotion || !("IntersectionObserver" in window)) {
    revealBlocks.forEach((block) => block.classList.add("is-split", "is-in"));
  } else {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-in");
          observer.unobserve(entry.target);
        });
      },
      { rootMargin: "0px 0px -10% 0px" }
    );

    // Wait for PP Mori so the lines break where they will finally sit.
    const fontsReady = document.fonts ? document.fonts.ready : Promise.resolve();
    Promise.race([fontsReady, new Promise((r) => setTimeout(r, 1500))]).then(() => {
      revealBlocks.forEach((block) => {
        splitBlock(block);
        observer.observe(block);
      });
      measureStack();
      updateStack();
    });
  }
}

// Row-by-row reveal: every row of a [data-reveal-rows] block has its own
// trigger, so the rows come in one at a time as they scroll into view.
// Rows that arrive together (a fast scroll) still enter 90ms apart.
const rowBlocks = [...document.querySelectorAll("[data-reveal-rows]")];
const ROW_GAP = 90;
let rowObserver = null;
const rowQueue = [];
const pendingRows = new Set();
let rowTimer = null;

function showRow(line) {
  pendingRows.delete(line);
  rowObserver?.unobserve(line);
  line.classList.add("is-in");
}

// A jump (anchor link, restored scroll) can skip rows past the screen
// without them ever crossing it, so their trigger never fires. Called on
// scroll: any row already above the screen just shows.
function showPassedRows() {
  pendingRows.forEach((line) => {
    if (line.getBoundingClientRect().bottom < 0) showRow(line);
  });
}

function queueRow(line) {
  rowQueue.push(line);
  if (rowTimer) return;
  (function next() {
    const row = rowQueue.shift();
    if (!row) {
      rowTimer = null;
      return;
    }
    showRow(row);
    rowTimer = setTimeout(next, ROW_GAP);
  })();
}

// After a re-split (resize), rows already on screen appear without animating
function setupRows(block, instant) {
  block.querySelectorAll("[data-lines]").forEach(splitParagraph);
  block.classList.add("is-split");
  block.querySelectorAll(".line").forEach((line) => {
    if (instant && line.getBoundingClientRect().top < innerHeight * 0.88) {
      line.classList.add("is-in");
      return;
    }
    pendingRows.add(line);
    rowObserver.observe(line);
  });
  showPassedRows();
}

if (rowBlocks.length) {
  if (reduceMotion || !("IntersectionObserver" in window)) {
    rowBlocks.forEach((block) => block.classList.add("is-split"));
  } else {
    rowObserver = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          rowObserver.unobserve(entry.target);
          queueRow(entry.target);
        });
      },
      { rootMargin: "0px 0px -12% 0px" }
    );
    const fontsReady = document.fonts ? document.fonts.ready : Promise.resolve();
    Promise.race([fontsReady, new Promise((r) => setTimeout(r, 1500))]).then(() =>
      rowBlocks.forEach((block) => setupRows(block, false))
    );
  }
}

// Hero card stack. Timeline matched frame by frame to the reference reels:
// the front card cuts in at full size on a flat colour and its edges pinch
// inwards (~0.15s), it holds for 0.66s, then the cards behind grow out
// around it (expo ease-out, 1.1s) from a slight 3D angle that settles flat,
// while the background cuts to white 0.1s into the grow. At rest the stack
// is a tunnel: each card behind is bigger than the one in front. The
// pointer then fans the stack gently toward it.
const heroEl = document.querySelector("[data-hero]");
const renderHero = heroEl ? createHero(heroEl) : null;

function createHero(hero) {
  const cards = [...hero.querySelectorAll(".stack-card")]; // front first
  const cardsWrap = hero.querySelector("[data-hero-cards]");
  const pillow = hero.querySelector("#pillow path");
  const copy = hero.querySelector("[data-hero-copy]");
  const rotator = hero.querySelector("[data-rotator]");
  const count = cards.length;
  const mid = (count - 1) / 2;

  const PINCH_IN = 0.15; // edges pinch inwards as the card appears
  const GROW_AT = 0.66; // the cards behind start growing
  const GROW = 1.1; // grow duration
  const TITLE_AT = GROW_AT + 0.45;
  const ENTRY_TILT = { x: 5, y: -9 }; // degrees, settles to flat with the grow

  // After the tunnel holds, the reel whips the stack into a fan toward the
  // top right (~0.15s), lets it drift, then (here) hands over to the pointer
  const FAN_AT = GROW_AT + 1.05;
  const FAN_SNAP = 0.2;
  const FAN_POS = { x: 0.72, y: -0.5 };
  const FAN_DRIFT = 1.3;
  const DRIFT_TO = { x: 0.58, y: -0.36 };
  const HANDOVER_AT = FAN_AT + FAN_SNAP + FAN_DRIFT;
  const HANDOVER = 1; // blend from the scripted fan to the live pointer

  const TUNNEL_STEP = 2.6 / (count - 1); // back card is 3.6x the front, as in the reel
  const MAX_SCALE = 1 + (count - 1) * TUNNEL_STEP; // cards are drawn at this size
  const GAP = 0.3; // gap between cards at full spread, in card widths
  const DRIFT = 0.05; // whole stack leans toward the pointer
  const TILT = 6; // degrees
  const FOLLOW_EASE = 3; // how quickly the stack catches up with the pointer

  const expoOut = (t) => (t >= 1 ? 1 : 1 - Math.pow(2, -10 * t));
  const cubicOut = (t) => 1 - Math.pow(1 - Math.min(1, t), 3);
  const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));

  // Rounded card with edges bowed inwards; pinch 1 is the resting shape
  const pillowPath = (pinch) => {
    const y = (0.05 * pinch).toFixed(4);
    const x = (0.035 * pinch).toFixed(4);
    return `M0.06 0 Q0.5 ${y} 0.94 0 Q1 0 1 0.087 Q${1 - x} 0.5 1 0.913 Q1 1 0.94 1 ` +
      `Q0.5 ${1 - y} 0.06 1 Q0 1 0 0.913 Q${x} 0.5 0 0.087 Q0 0 0.06 0 Z`;
  };
  let lastPinch = null;

  const pointer = { x: 0, y: 0 };
  const current = { x: 0, y: 0 };
  const canHover = matchMedia("(hover: hover) and (pointer: fine)").matches;
  let start = null;
  let last = null;
  let titleShown = false;
  let inView = true;
  let cardWidth, heroWidth, heroHeight;
  const measure = () => {
    cardWidth = cards[0].offsetWidth / MAX_SCALE; // the front card's width
    heroWidth = hero.offsetWidth;
    heroHeight = hero.offsetHeight;
  };
  measure();

  cards.forEach((card, i) => (card.style.zIndex = count - i));

  addEventListener("pointermove", (e) => {
    if (e.pointerType !== "mouse") return;
    const r = hero.getBoundingClientRect();
    pointer.x = clamp((e.clientX - (r.left + r.width / 2)) / (r.width / 2), -1, 1);
    pointer.y = clamp((e.clientY - (r.top + r.height / 2)) / (r.height / 2), -1, 1);
  });
  document.documentElement.addEventListener("mouseleave", () => {
    pointer.x = 0;
    pointer.y = 0;
  });
  addEventListener("resize", measure);
  new IntersectionObserver(([entry]) => (inView = entry.isIntersecting)).observe(hero);

  return function render(time) {
    if (start === null) start = time;
    const t = reduceMotion ? 99 : (time - start) / 1000;
    const dt = last === null ? 0 : Math.min(0.05, (time - last) / 1000);
    last = time;

    if (!titleShown && t >= TITLE_AT) {
      copy?.classList.add("is-in");
      if (rotator) startRotator(rotator);
      titleShown = true;
    }
    if (!inView && t > HANDOVER_AT + HANDOVER) return;

    // Card shape: pinch in as the front card appears, relax to rest with the grow
    const growAll = expoOut(clamp((t - GROW_AT) / GROW, 0, 1));
    const pinch = (0.2 + 1.2 * cubicOut(t / PINCH_IN)) * (1 - growAll) + 1 * growAll;
    const rounded = Math.round(pinch * 100) / 100;
    if (pillow && rounded !== lastPinch) {
      pillow.setAttribute("d", pillowPath(rounded));
      lastPinch = rounded;
    }

    // Scripted part of the intro: snap out to the fan, then drift
    let sx = 0;
    let sy = 0;
    if (t >= FAN_AT) {
      const snap = expoOut((t - FAN_AT) / FAN_SNAP);
      const d = clamp((t - FAN_AT - FAN_SNAP) / FAN_DRIFT, 0, 1);
      const drift = d * d * (3 - 2 * d);
      sx = (FAN_POS.x + (DRIFT_TO.x - FAN_POS.x) * drift) * snap;
      sy = (FAN_POS.y + (DRIFT_TO.y - FAN_POS.y) * drift) * snap;
    }

    // Live target: the mouse, or a slow drift on touch screens
    let tx = pointer.x;
    let ty = pointer.y;
    if (!canHover) {
      tx = Math.sin(t * 0.5) * 0.3;
      ty = Math.cos(t * 0.4) * 0.22;
    }

    if (reduceMotion) {
      current.x = 0;
      current.y = 0;
    } else if (t < HANDOVER_AT) {
      // Follow the script exactly so the snap stays as quick as the reel's
      current.x = sx;
      current.y = sy;
    } else {
      const h = clamp((t - HANDOVER_AT) / HANDOVER, 0, 1);
      const blend = h * h * (3 - 2 * h);
      const ease = 1 - Math.exp(-dt * FOLLOW_EASE);
      current.x += (sx + (tx - sx) * blend - current.x) * ease;
      current.y += (sy + (ty - sy) * blend - current.y) * ease;
    }

    const spread = Math.min(1, Math.hypot(current.x, current.y));
    const step = TUNNEL_STEP * (1 - 0.6 * spread);
    const gap = GAP * cardWidth;
    const driftX = current.x * DRIFT * (heroWidth / 2);
    const driftY = current.y * DRIFT * (heroHeight / 2);

    cards.forEach((card, i) => {
      const grow = expoOut(clamp((t - GROW_AT - i * 0.03) / GROW, 0, 1));
      const scale = (1 + i * step * grow) / MAX_SCALE;
      const x = driftX + (mid - i) * gap * current.x;
      const y = driftY + (mid - i) * gap * current.y;
      card.style.transform = `translate3d(${x}px, ${y}px, 0) scale(${scale})`;
      card.style.visibility = i === 0 || t >= GROW_AT ? "" : "hidden";
    });

    const settle = 1 - growAll;
    const rotX = ENTRY_TILT.x * settle - current.y * TILT;
    const rotY = ENTRY_TILT.y * settle + current.x * TILT;
    cardsWrap.style.transform = `rotateX(${rotX}deg) rotateY(${rotY}deg)`;
  };
}

// Header: on phones the links fold behind a "Menu" pill, and the pills
// change colour over the colour blocks.
const header = document.querySelector("[data-header]");
const nav = header?.querySelector("[data-nav]");
const navToggle = header?.querySelector("[data-nav-toggle]");
const colourBlocks = [...document.querySelectorAll("[data-card]")];
const smallScreen = matchMedia("(max-width: 760px)");

function setNav(open) {
  nav.classList.toggle("is-collapsed", !open);
  navToggle.setAttribute("aria-expanded", String(open));
}

if (nav && navToggle) {
  setNav(!smallScreen.matches);
  smallScreen.addEventListener("change", (e) => setNav(!e.matches));
  navToggle.addEventListener("click", () => setNav(nav.classList.contains("is-collapsed")));
  nav.querySelectorAll("a").forEach((link) =>
    link.addEventListener("click", () => smallScreen.matches && setNav(false))
  );
  addEventListener("keydown", (e) => {
    if (e.key === "Escape" && smallScreen.matches && !nav.classList.contains("is-collapsed")) {
      setNav(false);
      navToggle.focus();
    }
  });
}

function updateHeaderTone() {
  if (!header || !colourBlocks.length) return;
  const pill = header.querySelector(".pill").getBoundingClientRect();
  const y = pill.top + pill.height / 2;
  const onBlock = colourBlocks.some((block) => {
    const r = block.getBoundingClientRect();
    return r.top <= y && r.bottom >= y;
  });
  header.classList.toggle("is-on-blocks", onBlock);
}

// Rotating headline word: each word holds for 2.2s, then rolls like a reel
// (see --roll-ease in style.css): the next word drops in from above while
// the current one leaves below. The rows above never move. Reduced
// motion: CSS turns this into a plain fade.
function startRotator(slot) {
  const HOLD = 2200;
  const SWAP = 620;
  const words = slot.dataset.words.split("|").map((word) => `${word}.`);
  let index = 0;
  let current = slot.querySelector(".hero-title__word");

  const fit = () => (slot.style.width = `${current.offsetWidth}px`);
  fit();
  addEventListener("resize", fit);
  document.fonts?.ready.then(fit);

  setTimeout(function swap() {
    index = (index + 1) % words.length;
    const next = document.createElement("span");
    next.className = "hero-title__word is-entering";
    next.textContent = words[index];
    slot.append(next);

    // Reading the width also commits the start position, so the
    // transitions below run without waiting for a frame.
    slot.style.width = `${next.offsetWidth}px`;
    next.classList.remove("is-entering");
    const leaving = current;
    leaving.classList.add("is-leaving");
    setTimeout(() => leaving.remove(), SWAP);
    current = next;

    setTimeout(swap, HOLD + SWAP);
  }, HOLD);
}

// Button hover roll: wrap each button label in a two-row track, an
// identical copy above the original. CSS rolls the track down on hover.
function addRoll(target) {
  if (target.querySelector(":scope > .roll")) return;
  const text = target.textContent.trim();
  if (!text) return;

  const make = (hidden) => {
    const item = document.createElement("span");
    item.className = "roll__item";
    item.textContent = text;
    if (hidden) item.setAttribute("aria-hidden", "true");
    return item;
  };

  const roll = document.createElement("span");
  const track = document.createElement("span");
  roll.className = "roll";
  track.className = "roll__track";
  track.append(make(true), make(false));
  roll.append(track);
  target.replaceChildren(roll);
}

document
  .querySelectorAll(".site-header__cta, .site-nav__label, .site-nav__links a, .pill-link__text, .button, .chip")
  .forEach(addRoll);

let lastWidth = innerWidth;
addEventListener("resize", () => {
  if (innerWidth !== lastWidth) {
    lastWidth = innerWidth;
    revealBlocks.filter((b) => b.classList.contains("is-split")).forEach(splitBlock);
    if (rowObserver) {
      rowObserver.disconnect();
      pendingRows.clear();
      rowBlocks.filter((b) => b.classList.contains("is-split")).forEach((b) => setupRows(b, true));
    }
  }
  measureStack();
  updateStack();
});

measureStack();
let lastScroll = -1;
requestAnimationFrame(function frame(time) {
  lenis?.raf(time);
  if (scrollY !== lastScroll) {
    lastScroll = scrollY;
    updateStack();
    updateHeaderTone();
    if (pendingRows.size) showPassedRows();
  }
  renderHero?.(time);
  requestAnimationFrame(frame);
});
