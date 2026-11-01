# Linn Harrvik portfolio: project notes

A personal portfolio for Linn Harrvik, aimed at in-house content, social media, PR, copywriting and employer branding roles. It's plain HTML, CSS and JS with no build step: what's in the folder is what goes live. See `README.md` for the file layout, how to preview, the launch checklist and the domain setup.

## Working on it

- **Preview:** from this folder, run `python3 tools/serve.py` and open http://localhost:8796 (it turns caching off; plain `http.server` can serve stale CSS after a change). Opening the HTML files directly doesn't work, because paths start at `/`.
- **Fonts:** PP Mori (Pangram Pangram) is not in git. The free personal-use licence forbids uploading it. On a new computer, download "PP Mori – Free for personal use" from pangrampangram.com and copy these files into `assets/fonts/`:
  - `PPMori-Regular.otf`
  - `PPMori-RegularItalic.otf`
  - `PPMori-SemiBold.otf`
  - `PPMori-SemiBoldItalic.otf`
  - `PPMori-Extralight.otf`
  - `PPMori-ExtralightItalic.otf`

  Without them the site falls back to a system font. A paid web licence is needed before launch.
- **GitHub:** `Linnsan17/comms-portfolio` is private for now. At launch, rename it to `Linnsan17.github.io`, make it public and turn on GitHub Pages (main branch, root folder).
- **Code:** all behaviour is in `assets/js/main.js` and all styling is in `assets/css/style.css`. Every colour comes from the role tokens at the top of `style.css`.

## Home page, top to bottom

1. **Hero:** the intro animation, then a card stack that follows the mouse (the cards behind play footage from Linn's work, edge to edge: boat, dachshund, autumn tree, apartment block; the front card is a hand holding a phone, on the photo's own gradient (`--phone-gradient`); on its screen, over Linn's portrait (`assets/img/hero/phone-photo.jpg`), pink letters of LINN HARRVIK drop in with Matter.js physics and react to the mouse, with the top of the phone poking out above the card; see README "Hero phone"), with the headline "Making brands / matter through / [Content | Social Media | Strategy | Websites]." and a "Get in touch" button.
2. **Services:** the "Services" label and four stacked colour cards (Content, Social Media, Strategy, Website) that slow down and stack as you scroll, each with a work reel video. The label rides with the first card, so the gap between them never changes.
3. **Introduction:** "Introduction", then a big statement on the off-white band, revealed row by row on scroll.
4. **Toolbox:** "Toolbox" with a "View all" link to the About page's tools section, then the logo wave: the tools Linn works with (logos in `assets/img/tools/`), on white round badges riding a sine wave, still on the off-white band. Scrolling pushes the row along and the wave swells with speed, after the Osmo "wavy marquee" (measured frame by frame; the constants are in `createLogoWave` in `main.js`).
5. **Selected work:** "Selected work" with "Let’s join forces", then one full-width card per case: Boneo 01, Svedea 02, Nilar 03, each linking to its case page. Built 1:1 from wearemotto.com's areas of expertise at a 1537px window: as the next card rises, the covered one falls back to 62% of the scroll speed and a dark grey wash builds over it to 60%; the footer slides over the last card the same way. **The summaries, facts and videos are placeholders**; fill them in with each case page.
6. **Footer:** pink, rebuilt 1:1 from the Flow site's footer on a 12-column grid (on every page): Linn's portrait and "Ready to talk? Get in touch", then Navigate / Connect (email linnharrvik@gmail.com, which rolls to "Copy email" on hover and copies on click; phone +46 70 398 50 23; LinkedIn) / Open to, then the small print. It carries `#contact`, so every Contact and Let’s work link lands there, and on the home page it slides over the last work card. **Placeholders:** the LinkedIn link and `cv.pdf`; "Open to" is a draft. (The stats, about teaser and get-in-touch sections were removed on 2026-11-01; they're in git history.)

The "Selected work" section (case cards and filter) is removed for now; it's in git history before commit `3b4b232`. The case pages in `work/` still exist but have placeholder content.

## Decisions to keep

- **Section labels:** every section after the hero opens with a semibold label (no brackets) on the left and, where there is one, an underlined link on the right on the same baseline (`.section-head` in `style.css`, after wearemotto.com).

- **Palette ("Geometric" with light blue):**
  - Page background white #ffffff, with the off-white #f2f0ec only behind the introduction.
  - Text #1c1c1c.
  - Blocks: pink #fbbad4, rosewood #a45b61, blue #486adc, light blue #bfcef7.
  - Buttons pink. Nav pill warm beige #f2f0ec, no outline.
- **Type:** PP Mori everywhere. Buttons and nav are 600 weight at 19px (15px on phones). Labels are cap-centred: pills get 0.15em top padding, and every label holder is a flex container.
- **No arrows or icons** on buttons.
- **Motion:**
  - **Roll:** `--roll-ease` cubic-bezier(0.76, 0, 0.24, 1) over 620ms, used for the headline word and every button hover (the label rolls down).
  - **Smooth scroll:** Lenis 1.3.26 with lerp 0.1.
  - **Hero intro:**
    - The front card grows from 0 (hard ease), holds, and the rings grow out.
    - The header, logo writing, headline and button appear at the end.
    - The stack stays centred, then follows the mouse 1 second later.
  - **Services stack:** a card slows to 43.6% of scroll speed once its top passes 27% of the viewport.
- **Logo:** `assets/img/linn-logo.svg` is Linn's handwritten signature. `assets/img/linn-logo-write.svg` is a generated version that writes itself in, left to right per line. Regenerate it with the scripts in `tools/` if the logo changes (see README).
- **Videos:** `assets/video/` holds compressed work reels. Add new ones with `tools/transcode.swift` (see README).

## Source material

The original recordings, reference videos, raw work reels and logo files live in a separate working folder ("Linn_portfolio") outside this repo. They aren't needed to build the site; everything the site uses is in `assets/`.
