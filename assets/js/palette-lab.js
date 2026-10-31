// Colour panel for trying palettes while the site is in progress.
// It sets the colour roles defined at the top of style.css and remembers
// the choice in this browser only. Remove the <script> tag for this file
// from every page before launch (see README).

(() => {
  const STORE = "palette-lab";

  // [role, label, text-colour role for things placed on it]
  const ROLES = [
    ["paper", "Background"],
    ["ink", "Text"],
    ["block-1", "Block 1", "block-1-ink"],
    ["block-2", "Block 2", "block-2-ink"],
    ["block-3", "Block 3", "block-3-ink"],
    ["block-4", "Block 4", "block-4-ink"],
    ["pill", "Buttons", "pill-ink"],
    ["pill-on-blocks", "Buttons on blocks", "pill-on-blocks-ink"],
  ];

  // The gradient sampled from the phone photo (same as style.css)
  const PHONE_GRADIENT =
    "linear-gradient(180deg, #2a2622 0%, #342b2b 5%, #3f3136 10%, #4e3842 15%, #604050 20%, " +
    "#744a5d 25%, #87516a 30%, #9a5a79 35%, #af6388 40%, #c66a97 45%, #d5719e 50%, " +
    "#e877a8 55%, #f57ab1 60%, #ff7db6 65%, #fe78b1 70%, #ff75a8 75%, #ff719f 80%, " +
    "#ff6c92 85%, #fe6383 90%, #ff596d 95%, #fd4d5d 100%)";

  const black = "#000000";
  const white = "#ffffff";

  const PRESETS = [
    {
      name: "Figma palette",
      colours: {
        paper: white, ink: black,
        "block-1": "#f865ac", "block-1-ink": black,
        "block-2": "#fa2f30", "block-2-ink": black,
        "block-3": "#e4dacc", "block-3-ink": black,
        "block-4": "#efd4d8", "block-4-ink": black,
        pill: "#efd4d8", "pill-ink": black,
        "pill-on-blocks": white, "pill-on-blocks-ink": black,
      },
      gradient: ["#2a2622", "#d5719e", "#fd4d5d"],
      gradientCss: PHONE_GRADIENT,
    },
    {
      // Sampled from the blue and magenta reference boards
      name: "Blue & magenta",
      colours: {
        paper: white, ink: black,
        "block-1": "#0e0eff", "block-1-ink": white,
        "block-2": "#ff29fa", "block-2-ink": black,
        "block-3": "#eeebeb", "block-3-ink": black,
        "block-4": black, "block-4-ink": white,
        pill: black, "pill-ink": white,
        "pill-on-blocks": white, "pill-on-blocks-ink": black,
      },
      gradient: ["#0e0eff", "#8a1dfc", "#ff29fa"],
    },
    {
      // Pastel highlighter colours from the "We experiment." reference,
      // judged by eye (the image wasn't available as a file to sample)
      name: "Highlighters",
      colours: {
        paper: white, ink: black,
        "block-1": "#c4c8ff", "block-1-ink": black,
        "block-2": "#a7f59c", "block-2-ink": black,
        "block-3": "#fcfb86", "block-3-ink": black,
        "block-4": "#f0c4fa", "block-4-ink": black,
        pill: "#e9e9e9", "pill-ink": black,
        "pill-on-blocks": white, "pill-on-blocks-ink": black,
      },
      gradient: ["#c4c8ff", "#f0c4fa", "#ffd6b4"],
    },
    {
      name: "Mono",
      colours: {
        paper: white, ink: black,
        "block-1": black, "block-1-ink": white,
        "block-2": "#d9d9d9", "block-2-ink": black,
        "block-3": "#9a9a9a", "block-3-ink": black,
        "block-4": "#f1f1f1", "block-4-ink": black,
        pill: "#f1f1f1", "pill-ink": black,
        "pill-on-blocks": white, "pill-on-blocks-ink": black,
      },
      gradient: ["#000000", "#5c5c5c", "#d9d9d9"],
    },
    {
      name: "Citrus",
      colours: {
        paper: "#fbfaf5", ink: "#111111",
        "block-1": "#d7ff3e", "block-1-ink": black,
        "block-2": "#ff6b1a", "block-2-ink": black,
        "block-3": "#1b4332", "block-3-ink": white,
        "block-4": "#f1ece1", "block-4-ink": black,
        pill: "#d7ff3e", "pill-ink": black,
        "pill-on-blocks": white, "pill-on-blocks-ink": black,
      },
      gradient: ["#1b4332", "#7fa83a", "#ff6b1a"],
    },
  ];

  const root = document.documentElement;

  function read() {
    try {
      return JSON.parse(localStorage.getItem(STORE)) || null;
    } catch {
      return null;
    }
  }

  function save(state) {
    try {
      localStorage.setItem(STORE, JSON.stringify(state));
    } catch {
      /* private mode or blocked storage: the panel still works */
    }
  }

  function fromPreset(index) {
    const p = PRESETS[index];
    return { preset: index, colours: { ...p.colours }, gradient: [...p.gradient], customGradient: false };
  }

  function gradientCss(state) {
    const p = PRESETS[state.preset];
    if (!state.customGradient && p.gradientCss) return p.gradientCss;
    const [top, mid, bottom] = state.gradient;
    return `linear-gradient(180deg, ${top} 0%, ${mid} 50%, ${bottom} 100%)`;
  }

  function apply(state) {
    Object.entries(state.colours).forEach(([role, value]) => root.style.setProperty(`--${role}`, value));
    root.style.setProperty("--hero-gradient", gradientCss(state));
  }

  let state = read();
  if (!state || !PRESETS[state.preset]) state = fromPreset(0);
  apply(state);

  // ---- Panel ---------------------------------------------------------------

  const css = `
    .plab { position: fixed; left: 16px; bottom: 16px; z-index: 1000; font: 13px/1.3 system-ui, -apple-system, sans-serif; color: #fff; }
    .plab button { font: inherit; color: inherit; cursor: pointer; }
    .plab__toggle { display: inline-flex; align-items: center; gap: 8px; height: 36px; padding: 0 14px 0 10px; border: 0; border-radius: 999px; background: #111; }
    .plab__panel { position: absolute; left: 0; bottom: 44px; display: grid; gap: 14px; width: min(300px, calc(100vw - 32px)); max-height: calc(100vh - 110px); overflow: auto; padding: 14px; border-radius: 16px; background: #111; }
    .plab__panel[hidden] { display: none; }
    .plab__heading { margin: 0; color: #9a9a9a; font-size: 11px; }
    .plab__presets, .plab__rows { display: grid; gap: 6px; }
    .plab__preset { display: grid; grid-template-columns: 1fr auto; align-items: center; gap: 8px; padding: 8px 10px; border: 0; border-radius: 10px; background: #1d1d1d; text-align: left; }
    .plab__preset[aria-pressed="true"] { background: #fff; color: #111; }
    .plab__dots { display: flex; gap: 2px; }
    .plab__dot { width: 14px; height: 14px; border-radius: 50%; }
    .plab__row { display: grid; grid-template-columns: 1fr auto auto; align-items: center; gap: 6px; min-height: 28px; }
    .plab__row input[type="color"] { width: 34px; height: 26px; padding: 0; border: 0; border-radius: 6px; background: none; cursor: pointer; }
    .plab__ink { width: 30px; height: 26px; padding: 0; border: 0; border-radius: 6px; font-weight: 600; }
    .plab__stops { display: flex; gap: 4px; }
    .plab__actions { display: flex; gap: 6px; }
    .plab__action { flex: 1; height: 32px; border: 0; border-radius: 999px; background: #fff; color: #111 !important; }
    .plab__action--quiet { background: #2a2a2a; color: #fff !important; }
  `;

  function el(tag, props = {}, children = []) {
    const node = Object.assign(document.createElement(tag), props);
    node.append(...children);
    return node;
  }

  function dots(colours, keys) {
    const row = el("span", { className: "plab__dots" },
      keys.map((k) => {
        const d = el("span", { className: "plab__dot" });
        d.style.background = colours[k];
        return d;
      })
    );
    row.setAttribute("aria-hidden", "true");
    return row;
  }

  function build() {
    document.head.append(el("style", { textContent: css }));

    const panel = el("div", { className: "plab__panel", id: "plab-panel", hidden: true });
    const toggle = el("button", { className: "plab__toggle", type: "button" });
    toggle.setAttribute("aria-expanded", "false");
    toggle.setAttribute("aria-controls", "plab-panel");
    const wrap = el("div", { className: "plab" }, [panel, toggle]);

    function render() {
      apply(state);
      save(state);

      toggle.replaceChildren(dots(state.colours, ["block-1", "block-2", "block-3", "block-4"]), "Colours");

      const presets = el("div", { className: "plab__presets" },
        PRESETS.map((p, i) => {
          const b = el("button", { className: "plab__preset", type: "button" },
            [el("span", { textContent: p.name }), dots(p.colours, ["paper", "ink", "block-1", "block-2", "block-3", "block-4"])]);
          b.setAttribute("aria-pressed", String(state.preset === i));
          b.addEventListener("click", () => {
            state = fromPreset(i);
            render();
          });
          return b;
        })
      );

      const rows = el("div", { className: "plab__rows" },
        ROLES.map(([role, label, inkRole]) => {
          const input = el("input", { type: "color", value: state.colours[role], title: label });
          input.setAttribute("aria-label", label);
          input.addEventListener("input", () => {
            state.colours[role] = input.value;
            apply(state);
            save(state);
            if (ink) ink.style.background = input.value;
          });
          let ink = null;
          if (inkRole) {
            ink = el("button", { className: "plab__ink", type: "button", textContent: "Aa", title: `Text on ${label.toLowerCase()}: switch black / white` });
            ink.setAttribute("aria-label", `Text colour on ${label.toLowerCase()}, switch black or white`);
            ink.style.background = state.colours[role];
            ink.style.color = state.colours[inkRole];
            ink.addEventListener("click", () => {
              state.colours[inkRole] = state.colours[inkRole].toLowerCase() === white ? black : white;
              ink.style.color = state.colours[inkRole];
              apply(state);
              save(state);
            });
          }
          return el("div", { className: "plab__row" }, [el("span", { textContent: label }), ink || el("span"), input]);
        })
      );

      const stops = el("span", { className: "plab__stops" },
        ["Top", "Middle", "Bottom"].map((name, i) => {
          const input = el("input", { type: "color", value: state.gradient[i], title: `Gradient ${name.toLowerCase()}` });
          input.setAttribute("aria-label", `Gradient ${name.toLowerCase()}`);
          input.addEventListener("input", () => {
            state.gradient[i] = input.value;
            state.customGradient = true;
            apply(state);
            save(state);
          });
          return input;
        })
      );
      rows.append(el("div", { className: "plab__row" }, [el("span", { textContent: "Gradient" }), el("span"), stops]));

      const copy = el("button", { className: "plab__action", type: "button", textContent: "Copy CSS" });
      copy.addEventListener("click", async () => {
        const lines = Object.entries(state.colours).map(([k, v]) => `  --${k}: ${v};`);
        lines.push(`  --hero-gradient: ${gradientCss(state)};`);
        const text = `:root {\n${lines.join("\n")}\n}`;
        try {
          await navigator.clipboard.writeText(text);
          copy.textContent = "Copied";
        } catch {
          window.prompt("Copy the colours:", text);
        }
        setTimeout(() => (copy.textContent = "Copy CSS"), 1500);
      });
      const reset = el("button", { className: "plab__action plab__action--quiet", type: "button", textContent: "Reset" });
      reset.addEventListener("click", () => {
        state = fromPreset(state.preset);
        render();
      });

      panel.replaceChildren(
        el("p", { className: "plab__heading", textContent: "Palettes" }), presets,
        el("p", { className: "plab__heading", textContent: "Adjust" }), rows,
        el("div", { className: "plab__actions" }, [copy, reset])
      );
    }

    function setOpen(open) {
      panel.hidden = !open;
      toggle.setAttribute("aria-expanded", String(open));
    }

    toggle.addEventListener("click", () => setOpen(panel.hidden));
    addEventListener("keydown", (e) => {
      if (e.key === "Escape" && !panel.hidden) {
        setOpen(false);
        toggle.focus();
      }
    });

    render();
    document.body.append(wrap);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", build);
  else build();
})();
