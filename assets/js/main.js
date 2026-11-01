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
// The section label rides with the first card, so the gap between them
// never changes while that card slows down
const stackLabel = document.querySelector(".services__head");
let naturalTops = [];

function measureStack() {
  stackCards.forEach((card) => (card.style.transform = ""));
  if (stackLabel) stackLabel.style.transform = "";
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
  if (stackLabel) stackLabel.style.transform = stackCards[0].style.transform;
}

// Selected work, after wearemotto.com's areas of expertise (measured frame
// by frame): each card scrolls normally until the next card, or after the
// last one whatever follows on the page, comes up from the bottom of the
// screen. From then until
// it is fully covered, the card falls behind to AREA_SPEED of the scroll
// and a dark grey wash builds up over it, to AREA_DIM when covered.
const AREA_SPEED = 0.62;
const AREA_DIM = 0.6;

const areaCards = reduceMotion ? [] : [...document.querySelectorAll("[data-area]")];
// The next thing on the page after an element, climbing out of its parents
function nextOnPage(el) {
  for (; el; el = el.parentElement) if (el.nextElementSibling) return el.nextElementSibling;
  return null;
}
const areaFollowers = areaCards.map((card, i) => areaCards[i + 1] || nextOnPage(card.closest("section")));

// Position in the page from layout alone, so the cards' own movement
// doesn't feed back into it
function pageTop(el) {
  let top = 0;
  for (; el; el = el.offsetParent) top += el.offsetTop;
  return top;
}

function updateAreas() {
  const vh = innerHeight;
  areaCards.forEach((card, i) => {
    const follower = areaFollowers[i];
    if (!follower) return;
    const risen = Math.min(Math.max(vh - (pageTop(follower) - scrollY), 0), vh);
    card.style.transform = risen ? `translate3d(0, ${risen * (1 - AREA_SPEED)}px, 0)` : "";
    card.style.setProperty("--dim", ((risen / vh) * AREA_DIM).toFixed(3));
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

// Stats: each number counts up from 0 when its row scrolls into view, fast
// at first and settling into place (expo ease-out, 1.6s). Numbers already
// scrolled past just show. Reduced motion shows the final numbers.
const counters = [...document.querySelectorAll("[data-count]")];
const pendingCounts = new Set();
const COUNT_TIME = 1600;

function runCount(el) {
  pendingCounts.delete(el);
  const target = Number(el.dataset.count);
  const start = performance.now();
  (function tick(now) {
    const k = Math.min(1, (now - start) / COUNT_TIME);
    const eased = k >= 1 ? 1 : 1 - Math.pow(2, -10 * k);
    el.textContent = String(Math.round(target * eased));
    if (k < 1) requestAnimationFrame(tick);
  })(start);
}

function showPassedCounts() {
  pendingCounts.forEach((el) => {
    if (el.getBoundingClientRect().bottom < 0) {
      pendingCounts.delete(el);
      el.textContent = el.dataset.count;
    }
  });
}

if (counters.length && !reduceMotion && "IntersectionObserver" in window) {
  const countObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        countObserver.unobserve(entry.target);
        runCount(entry.target);
      });
    },
    { rootMargin: "0px 0px -15% 0px" }
  );
  counters.forEach((el) => {
    el.textContent = "0";
    pendingCounts.add(el);
    countObserver.observe(el);
  });
}

// Handwritten logo: the header's logo image is swapped for the "written"
// version (assets/img/linn-logo-write.svg), where a mask of pen strokes
// traced along the letters draws the signature in when the header appears.
// The mask comes off at the end, so the finished logo is the original
// artwork. Reduced motion keeps the plain image.
const logoLink = document.querySelector(".site-header__logo");
let logoSvg = null;
let logoWanted = false;

function writeLogo() {
  logoWanted = true;
  if (!logoSvg || logoSvg.classList.contains("is-writing")) return;
  logoSvg.getBoundingClientRect(); // commit the hidden start state first
  logoSvg.classList.add("is-writing");
  const total = Number(logoSvg.dataset.writeDuration) || 2600;
  setTimeout(() => logoSvg.classList.add("is-written"), total + 150);
}

if (logoLink) {
  const img = logoLink.querySelector("img");
  if (reduceMotion) {
    logoLink.classList.add("is-ready");
  } else {
    fetch("/assets/img/linn-logo-write.svg")
      .then((r) => (r.ok ? r.text() : Promise.reject(r.status)))
      .then((text) => {
        const parsed = new DOMParser().parseFromString(text, "image/svg+xml").documentElement;
        const svg = document.importNode(parsed, true);
        svg.classList.add("logo-write");
        svg.setAttribute("role", "img");
        svg.setAttribute("aria-label", img?.alt || "Linn Harrvik");
        svg.setAttribute("focusable", "false");
        logoLink.replaceChildren(svg);
        logoSvg = svg;
        logoLink.classList.add("is-ready");
        if (logoWanted) writeLogo();
      })
      .catch(() => logoLink.classList.add("is-ready"));
  }
}

// Hero card stack. Sequence from the reference reel, with every step on a
// hard ease-in-out (the site's --roll-ease curve): the front card grows
// from nothing, holds, then the cards behind grow out around it from a
// slight 3D angle that settles flat. The stack stays
// perfectly centred while the header, headline and button appear; one
// second later it swings straight to wherever the mouse is and follows it.
const heroEl = document.querySelector("[data-hero]");
const renderHero = heroEl ? createHero(heroEl) : null;

// Header and hero copy wait for the intro; show them straight away when
// there is no intro, and as a safety net if the animation never finishes
function introDone() {
  document.documentElement.classList.add("intro-done");
  writeLogo();
}
if (!heroEl || reduceMotion) introDone();
else setTimeout(introDone, 6000);

function createHero(hero) {
  const cards = [...hero.querySelectorAll(".stack-card")]; // front first
  const cardsWrap = hero.querySelector("[data-hero-cards]");
  const copy = hero.querySelector("[data-hero-copy]");
  const rotator = hero.querySelector("[data-rotator]");
  const count = cards.length;
  const mid = (count - 1) / 2;

  const APPEAR = 0.6; // front card grows from nothing
  const GROW_AT = APPEAR + 0.3; // the cards behind start growing
  const GROW = 0.9;
  const DONE_AT = GROW_AT + GROW; // header, headline and button appear
  const FOLLOW_AT = DONE_AT + 1; // centred until now, then follow the mouse
  const SWING = 0.5; // swing straight to the mouse, hard eased
  const ENTRY_TILT = { x: 5, y: -9 }; // degrees, settles to flat with the grow

  const TUNNEL_STEP = 2.6 / (count - 1); // back card is 3.6x the front, as in the reel
  const MAX_SCALE = 1 + (count - 1) * TUNNEL_STEP; // cards are drawn at this size
  const GAP = 0.3; // gap between cards at full spread, in card widths
  const DRIFT = 0.05; // whole stack leans toward the pointer
  const TILT = 6; // degrees
  const FOLLOW_EASE = 3; // how quickly the stack catches up with the pointer

  const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
  // Hard ease-in-out, the same curve as --roll-ease: cubic-bezier(0.76, 0, 0.24, 1)
  const hard = (t) => {
    t = clamp(t, 0, 1);
    return t < 0.5 ? 8 * t ** 4 : 1 - (-2 * t + 2) ** 4 / 2;
  };

  // Front card's phone: a reel plays under a hole in the photo, warped
  // onto the phone's screen. Its corners (top left, top right, bottom right,
  // bottom left), a little under the bezel, as fractions of the cut-out;
  // from tools/phone_cutout.py.
  const PHONE_SCREEN = [[0.05982, 0.00468], [0.35087, 0.01835], [0.40403, 0.70095], [0.1368, 0.70877]];
  const SCREEN_ASPECT = 0.487; // a phone's face, width to height
  const phoneLayer = hero.querySelector(".stack-card__phone");
  const phoneArt = hero.querySelector("[data-phone]");
  const phoneScreen = hero.querySelector("[data-phone-screen]");
  const placeScreen = () => {
    const w = phoneArt.offsetWidth;
    const h = phoneArt.offsetHeight;
    if (!w || !h) return;
    const quad = PHONE_SCREEN.map(([x, y]) => [x * w, y * h]);
    // About its size on the page, so the warp barely scales it and the
    // reel stays sharp
    const width = Math.hypot(quad[1][0] - quad[0][0], quad[1][1] - quad[0][1]);
    phoneScreen.style.width = `${width}px`;
    phoneScreen.style.height = `${width / SCREEN_ASPECT}px`;
    phoneScreen.style.borderRadius = `${width * 0.13}px`;
    phoneScreen.style.transform = quadMatrix(width, width / SCREEN_ASPECT, quad);
    phoneScreen.classList.add("is-placed");
  };
  if (phoneArt && phoneScreen) new ResizeObserver(placeScreen).observe(phoneArt);

  // The phone layer's clip: the card's rounded rectangle, rx and ry its
  // corners as shares of its width and height, plus everything above the
  // top edge so the phone pokes out
  const popPolygon = (rx, ry) => {
    const pts = [[-0.2, -1], [1.2, -1], [1.2, 0.04], [1, 0.04]];
    const arc = (cx, cy, from) => {
      for (let i = 0; i <= 6; i++) {
        const a = from + (Math.PI / 2) * (i / 6);
        pts.push([cx + rx * Math.cos(a), cy + ry * Math.sin(a)]);
      }
    };
    arc(1 - rx, 1 - ry, 0);
    arc(rx, 1 - ry, Math.PI / 2);
    pts.push([0, 0.04], [-0.2, 0.04]);
    return toPolygon(pts);
  };
  const toPolygon = (pts) =>
    `polygon(${pts.map(([px, py]) => `${(px * 100).toFixed(2)}% ${(py * 100).toFixed(2)}%`).join(",")})`;
  const CORNER = 16; // px on screen, a little rounder than --radius-media for the bigger cards
  let lastClip = null;

  const pointer = { x: 0, y: 0 };
  const current = { x: 0, y: 0 };
  const canHover = matchMedia("(hover: hover) and (pointer: fine)").matches;
  let start = null;
  let last = null;
  let done = false;
  let inView = true;
  let cardWidth, heroWidth, heroHeight;
  // The front card is drawn at its own size (see .stack-card in the CSS);
  // the rest at the back card's. Each card's scale makes up the difference.
  cards[0].style.setProperty("--shrink", MAX_SCALE);

  let drawn = [];
  const measure = () => {
    const full = Math.max(...cards.map((card) => card.offsetWidth));
    drawn = cards.map((card) => full / card.offsetWidth);
    cardWidth = full / MAX_SCALE; // the front card's width
    heroWidth = hero.offsetWidth;
    heroHeight = hero.offsetHeight;
  };
  measure();
  // Measure again if the styles settle after this has run
  new ResizeObserver(measure).observe(cards[0]);

  cards.forEach((card, i) => (card.style.zIndex = count - i));

  // Where the headline crosses the cards it turns white: a white copy of
  // it, laid exactly over the black one, shows only over the cards.
  // Markers on each card's corners (and the phone screen's) show where
  // those shapes land on the page, however they're scaled and tilted.
  const title = hero.querySelector(".hero-title");
  const titleStack = document.createElement("div");
  titleStack.className = "hero-title-stack";
  title.before(titleStack);
  titleStack.append(title);
  const lightTitle = title.cloneNode(true);
  lightTitle.removeAttribute("id");
  lightTitle.setAttribute("aria-hidden", "true");
  lightTitle.classList.add("hero-title--light");
  titleStack.append(lightTitle);
  const markCorners = (el) =>
    [0, 1, 2, 3].map((n) => {
      const mark = document.createElement("i");
      mark.className = "corner-mark";
      mark.dataset.corner = n;
      el.append(mark);
      return mark;
    });
  const quads = [...cards.map(markCorners), ...(phoneScreen ? [markCorners(phoneScreen)] : [])];

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

    if (!done && t >= DONE_AT) {
      done = true;
      introDone();
      copy?.classList.add("is-in");
      if (rotator) startRotator([...hero.querySelectorAll("[data-rotator]")]);
    }
    if (!inView && t > FOLLOW_AT + SWING) return;

    const appear = hard(t / APPEAR);
    const growAll = hard((t - GROW_AT) / GROW);

    // Live target: the mouse, or a slow drift on touch screens
    let tx = pointer.x;
    let ty = pointer.y;
    if (!canHover) {
      tx = Math.sin(t * 0.5) * 0.3;
      ty = Math.cos(t * 0.4) * 0.22;
    }

    if (reduceMotion || t < FOLLOW_AT) {
      // Perfectly centred through the intro and the first second after it
      current.x = 0;
      current.y = 0;
    } else if (t < FOLLOW_AT + SWING) {
      // Swing straight to where the mouse is now
      const swing = hard((t - FOLLOW_AT) / SWING);
      current.x = tx * swing;
      current.y = ty * swing;
    } else {
      const ease = 1 - Math.exp(-dt * FOLLOW_EASE);
      current.x += (tx - current.x) * ease;
      current.y += (ty - current.y) * ease;
    }

    const spread = Math.min(1, Math.hypot(current.x, current.y));
    const step = TUNNEL_STEP * (1 - 0.6 * spread);
    const gap = GAP * cardWidth;
    const driftX = current.x * DRIFT * (heroWidth / 2);
    const driftY = current.y * DRIFT * (heroHeight / 2);

    cards.forEach((card, i) => {
      const grow = hard((t - GROW_AT - i * 0.03) / GROW);
      const scale = ((appear * (1 + i * step * grow)) / MAX_SCALE) * drawn[i];
      const x = driftX + (mid - i) * gap * current.x;
      const y = driftY + (mid - i) * gap * current.y;
      card.style.transform = `translate3d(${x}px, ${y}px, 0) scale(${scale})`;
      card.style.visibility = i === 0 || t >= GROW_AT ? "" : "hidden";
      // Corners that stay the same on screen however far the card is scaled
      card.style.setProperty("--corner", `${(CORNER / Math.max(scale, 0.05)).toFixed(1)}px`);
    });

    // The headline copy shows only over the cards and the phone screen
    {
      const box = lightTitle.getBoundingClientRect();
      const path = quads
        .map(
          (quad) =>
            quad
              .map((mark, n) => {
                const r = mark.getBoundingClientRect();
                return `${n ? "L" : "M"}${(r.left - box.left).toFixed(1)} ${(r.top - box.top).toFixed(1)}`;
              })
              .join("") + "Z"
        )
        .join("");
      lightTitle.style.clipPath = `path("${path}")`;
    }

    // The phone layer's clip follows the front card's corners
    if (phoneLayer) {
      const corner = cards[0].style.getPropertyValue("--corner");
      if (corner !== lastClip) {
        const r = parseFloat(corner);
        phoneLayer.style.clipPath = popPolygon(Math.min(0.5, r / cards[0].offsetWidth), Math.min(0.5, r / cards[0].offsetHeight));
        lastClip = corner;
      }
    }

    const settle = 1 - growAll;
    const rotX = ENTRY_TILT.x * settle - current.y * TILT;
    const rotY = ENTRY_TILT.y * settle + current.x * TILT;
    cardsWrap.style.transform = `rotateX(${rotX}deg) rotateY(${rotY}deg)`;
  };
}

// Logo wave, after the Osmo wavy marquee (measured frame by frame): round
// badges ride one sine wave about 1.5 screens long. Scrolling pushes them
// along, left when scrolling down and right when scrolling up, and they
// keep drifting slowly the way you last scrolled. While they move, the
// wave slides against them at a quarter of their speed and swells, up to
// 65% taller at speed, settling back as they slow. Reduced motion: a still
// wave.
const waveEl = document.querySelector("[data-logo-wave]");
const renderLogoWave = waveEl ? createLogoWave(waveEl) : null;

function createLogoWave(section) {
  const list = section.querySelector(".logo-wave__list");
  const originals = [...list.children];
  const PITCH = 1.128; // badge to badge, in badge widths
  const WAVE_LENGTH = 1.53; // in screen widths
  const WAVE_HEIGHT = 0.254; // up and down from the middle, in badge widths
  const PHASE = 1.13; // starts low on the left, rising to the right
  const TRAVEL = 0.25; // the wave slides against the badges at this share of their speed
  const SWELL = 0.65; // the wave grows this much taller at full speed...
  const SWELL_SPEED = 1.2; // ...which is 1.2 screen widths a second
  const DRIFT = 0.06; // idle speed, in screen widths a second
  const SCROLL_PUSH = 0.5; // badges move this share of the scroll distance
  const MAX_SPEED = 2.5; // screen widths a second, so a jump doesn't fling them
  let items = [];
  let width = 0;
  let size = 0;
  let pitch = 0;
  let track = 0;
  let offset = 0;
  let dir = -1;
  let speed = 0;
  let swell = 0;
  let lastY = scrollY;
  let last = null;
  let inView = false;

  // Repeat the badges until they cover the screen with one spare on each
  // side, in whole rounds so the order never breaks where the row wraps.
  // Until the styles apply, a badge is as wide as the page; measuring then
  // would space them a page apart with a wave as tall, so wait.
  function measure() {
    const sectionWidth = section.clientWidth;
    const badge = originals[0].offsetWidth;
    if (!badge || badge >= sectionWidth) return false;
    width = sectionWidth;
    size = badge;
    pitch = size * PITCH;
    const per = originals.length;
    const count = Math.ceil((Math.ceil(width / pitch) + 2) / per) * per;
    list.querySelectorAll("[data-clone]").forEach((clone) => clone.remove());
    items = [...originals];
    for (let i = per; i < count; i++) {
      const clone = originals[i % per].cloneNode(true);
      clone.dataset.clone = "";
      clone.setAttribute("aria-hidden", "true");
      list.append(clone);
      items.push(clone);
    }
    track = items.length * pitch;
    return true;
  }

  function place() {
    if (!track) return;
    const k = (2 * Math.PI) / (WAVE_LENGTH * width);
    const height = WAVE_HEIGHT * size * (1 + swell);
    const phase = PHASE + TRAVEL * k * offset;
    items.forEach((item, i) => {
      const x = ((((i * pitch + offset) % track) + track) % track) - pitch;
      const y = height * Math.sin(k * (x + size / 2) + phase);
      item.style.transform = `translate3d(${x}px, ${y}px, 0)`;
    });
  }

  // Measure whenever the section or a badge changes size: on resize, and
  // whenever the styles settle after this script has run. The row stays
  // hidden until it has been placed once.
  function fit() {
    if (!measure()) return;
    place();
    section.classList.add("is-ready");
  }
  fit();
  const resizes = new ResizeObserver(fit);
  resizes.observe(section);
  resizes.observe(originals[0]);
  if (reduceMotion) return null;
  new IntersectionObserver(([entry]) => (inView = entry.isIntersecting), {
    rootMargin: "100px 0px",
  }).observe(section);

  return function render(time) {
    const dt = last === null ? 0 : Math.min(0.05, (time - last) / 1000);
    const dy = scrollY - lastY;
    last = time;
    lastY = scrollY;
    if (!dt) return;
    // More than a screen in one frame is a jump, not a scroll: the browser
    // restoring the position on reload, or the start of a long anchor scroll
    const jump = Math.abs(dy) > innerHeight;
    if (dy && !jump) dir = dy > 0 ? -1 : 1;
    const push = jump ? 0 : Math.min(MAX_SPEED * width, (Math.abs(dy) / dt) * SCROLL_PUSH);
    const target = dir * (DRIFT * width + push);
    speed += (target - speed) * (1 - Math.exp(-dt / 0.12));
    offset += speed * dt;
    const swellTo = SWELL * Math.min(1, Math.abs(speed) / (SWELL_SPEED * width));
    swell += (swellTo - swell) * (1 - Math.exp(-dt / 0.1));
    // Keep moving off screen so it comes back the way it's going, but only
    // touch the page while it's in view
    if (inView) place();
  };
}

// The perspective warp of a unit square onto a quad (top left, top right,
// bottom right, bottom left): a point (u, v) lands on
// ((a u + b v + x0) / (g u + k v + 1), (d u + e v + y0) / (g u + k v + 1))
function squareToQuad([[x0, y0], [x1, y1], [x2, y2], [x3, y3]]) {
  const dx1 = x1 - x2;
  const dx2 = x3 - x2;
  const dx3 = x0 - x1 + x2 - x3;
  const dy1 = y1 - y2;
  const dy2 = y3 - y2;
  const dy3 = y0 - y1 + y2 - y3;
  const den = dx1 * dy2 - dx2 * dy1;
  const g = (dx3 * dy2 - dx2 * dy3) / den;
  const k = (dx1 * dy3 - dx3 * dy1) / den;
  return { a: x1 - x0 + g * x1, b: x3 - x0 + k * x3, d: y1 - y0 + g * y1, e: y3 - y0 + k * y3, g, k, x0, y0 };
}

// The CSS matrix3d that warps a w×h box onto a quad, for laying flat
// content onto a photo
function quadMatrix(w, h, quad) {
  const { a, b, d, e, g, k, x0, y0 } = squareToQuad(quad);
  return `matrix3d(${a / w},${d / w},0,${g / w},${b / h},${e / h},0,${k / h},0,0,1,0,${x0},${y0},0,1)`;
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
// Several slots (the headline and any copy of it) roll in step. On phones
// the words come from data-words-short where a word is too long to fit.
function startRotator(slots) {
  const HOLD = 2200;
  const SWAP = 620;
  const words = slots[0].dataset.words.split("|").map((word) => `${word}.`);
  const short = (slots[0].dataset.wordsShort || slots[0].dataset.words).split("|").map((word) => `${word}.`);
  let index = 0;
  let current = slots.map((slot) => slot.querySelector(".hero-title__word"));

  const fit = () => slots.forEach((slot, i) => (slot.style.width = `${current[i].offsetWidth}px`));
  fit();
  addEventListener("resize", fit);
  document.fonts?.ready.then(fit);

  setTimeout(function swap() {
    index = (index + 1) % words.length;
    current = slots.map((slot, i) => {
      const next = document.createElement("span");
      next.className = "hero-title__word is-entering";
      next.textContent = (smallScreen.matches ? short : words)[index];
      slot.append(next);

      // Reading the width also commits the start position, so the
      // transitions below run without waiting for a frame.
      slot.style.width = `${next.offsetWidth}px`;
      next.classList.remove("is-entering");
      const leaving = current[i];
      leaving.classList.add("is-leaving");
      setTimeout(() => leaving.remove(), SWAP);
      return next;
    });

    setTimeout(swap, HOLD + SWAP);
  }, HOLD);
}

// Work reels: muted, looping, inline videos that only load and play while
// near the screen, to save data and battery. On phones only the front hero
// card plays; the cards behind it keep their poster. Reduced motion keeps
// every video on its poster.
const reels = [...document.querySelectorAll("video[data-autoplay]")].filter((video) => {
  const card = video.closest(".stack-card");
  return !(smallScreen.matches && card && card !== card.parentElement.firstElementChild);
});

if (reels.length && !reduceMotion && "IntersectionObserver" in window) {
  const reelObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach(({ target, isIntersecting }) => {
        if (isIntersecting) target.play().catch(() => {});
        else target.pause();
      });
    },
    { rootMargin: "200px 0px" }
  );
  reels.forEach((video) => reelObserver.observe(video));
}

// Button hover roll: wrap each button label in a two-row track, an
// identical copy above the original. CSS rolls the track down on hover.
function addRoll(target) {
  if (target.querySelector(":scope > .roll")) return;
  const text = target.textContent.trim();
  if (!text) return;

  // The copy that rolls in on hover can say something else (data-hover)
  const make = (hidden) => {
    const item = document.createElement("span");
    item.className = "roll__item";
    item.textContent = hidden ? target.dataset.hover || text : text;
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
  .querySelectorAll(
    ".site-header__cta-label, .site-nav__label, .site-nav__links a, .pill-link__text, .button, .chip, .section-head__link, .site-footer a"
  )
  .forEach(addRoll);

// Footer email: hovering rolls in "Copy email", and a click copies the
// address and says so for a moment. Without a clipboard the link just opens
// the mail app.
document.querySelectorAll("[data-copy]").forEach((link) => {
  link.addEventListener("click", (e) => {
    if (!navigator.clipboard) return;
    e.preventDefault();
    navigator.clipboard.writeText(link.dataset.copy).then(
      () => {
        const label = link.querySelector(".roll__item");
        if (!label) return;
        label.textContent = "Copied";
        setTimeout(() => (label.textContent = link.dataset.hover), 1600);
      },
      () => (location.href = link.href)
    );
  });
});

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
  updateAreas();
});

measureStack();
// Fonts and media can settle after this runs and move the cards down the
// page, so measure again whenever the page changes height
if (stackCards.length) {
  new ResizeObserver(() => {
    measureStack();
    updateStack();
  }).observe(document.body);
}
let lastScroll = -1;
requestAnimationFrame(function frame(time) {
  lenis?.raf(time);
  if (scrollY !== lastScroll) {
    lastScroll = scrollY;
    updateStack();
    updateAreas();
    updateHeaderTone();
    if (pendingRows.size) showPassedRows();
    if (pendingCounts.size) showPassedCounts();
  }
  renderHero?.(time);
  renderLogoWave?.(time);
  requestAnimationFrame(frame);
});
