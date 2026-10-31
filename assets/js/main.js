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
  requestAnimationFrame(frame);
});
