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
    // Blocks marked data-reveal-manual are revealed by their own code.
    const fontsReady = document.fonts ? document.fonts.ready : Promise.resolve();
    Promise.race([fontsReady, new Promise((r) => setTimeout(r, 1500))]).then(() => {
      revealBlocks.forEach((block) => {
        splitBlock(block);
        if (!block.hasAttribute("data-reveal-manual")) observer.observe(block);
      });
      measureStack();
      updateStack();
    });
  }
}

// Hero card stack. Timeline measured from the reference reel:
// the front card pops in on lavender, holds, then the cards behind grow
// out around it (expo ease-out, 1.1s) and the background cuts to white
// 0.11s into the grow. At rest the stack is a tunnel: each card behind is
// bigger than the one in front. The pointer then fans the stack toward it,
// with wider gaps the further the pointer is from the centre.
const heroEl = document.querySelector("[data-hero]");
const renderHero = heroEl ? createHero(heroEl) : null;

function createHero(hero) {
  const cards = [...hero.querySelectorAll(".stack-card")]; // front first
  const cardsWrap = hero.querySelector("[data-hero-cards]");
  const title = hero.querySelector("[data-reveal-manual]");
  const count = cards.length;
  const mid = (count - 1) / 2;

  const POP = 0.5; // front card pops in
  const GROW_AT = 1.1; // the cards behind start growing
  const GROW = 1.1; // grow duration
  const WHITE_AT = GROW_AT + 0.11; // background cuts to white
  const TITLE_AT = 1.35;
  const FOLLOW_AT = 1.6; // pointer takes over, fading in over 0.8s

  const TUNNEL_STEP = 0.52; // each card behind is this much bigger at rest
  const MAX_SCALE = 1 + (count - 1) * TUNNEL_STEP; // cards are drawn at this size
  const GAP = 0.45; // gap between cards at full spread, in card widths
  const DRIFT = 0.12; // whole stack leans toward the pointer
  const TILT = 10; // degrees

  const expoOut = (t) => (t >= 1 ? 1 : 1 - Math.pow(2, -10 * t));
  const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));

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

    if (!titleShown && t >= TITLE_AT && title?.classList.contains("is-split")) {
      title.classList.add("is-in");
      titleShown = true;
    }
    hero.classList.toggle("is-intro", t < WHITE_AT);
    if (!inView && t > FOLLOW_AT + 1) return;

    // Where the stack is heading: the mouse, or a slow drift on touch screens
    let tx = pointer.x;
    let ty = pointer.y;
    if (!canHover) {
      tx = Math.sin(t * 0.6) * 0.45;
      ty = Math.cos(t * 0.45) * 0.35;
    }
    const follow = reduceMotion ? 0 : clamp((t - FOLLOW_AT) / 0.8, 0, 1);
    const ease = 1 - Math.exp(-dt * 5);
    current.x += (tx * follow - current.x) * ease;
    current.y += (ty * follow - current.y) * ease;

    const spread = Math.min(1, Math.hypot(current.x, current.y));
    const step = TUNNEL_STEP * (1 - 0.85 * spread);
    const gap = GAP * cardWidth;
    const driftX = current.x * DRIFT * (heroWidth / 2);
    const driftY = current.y * DRIFT * (heroHeight / 2);
    const pop = expoOut(t / POP);

    cards.forEach((card, i) => {
      const grow = expoOut(clamp((t - GROW_AT - i * 0.03) / GROW, 0, 1));
      const scale = (pop * (1 + i * step * grow)) / MAX_SCALE;
      const x = driftX + (mid - i) * gap * current.x;
      const y = driftY + (mid - i) * gap * current.y;
      card.style.transform = `translate3d(${x}px, ${y}px, 0) scale(${scale})`;
      card.style.visibility = i === 0 || t >= GROW_AT ? "" : "hidden";
    });
    cardsWrap.style.transform = `rotateX(${-current.y * TILT}deg) rotateY(${current.x * TILT}deg)`;
  };
}

let lastWidth = innerWidth;
addEventListener("resize", () => {
  if (innerWidth !== lastWidth) {
    lastWidth = innerWidth;
    revealBlocks.filter((b) => b.classList.contains("is-split")).forEach(splitBlock);
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
  }
  renderHero?.(time);
  requestAnimationFrame(frame);
});
