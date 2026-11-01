# Linn Harrvik portfolio: project notes

A personal portfolio for Linn Harrvik, aimed at in-house content, social media, PR, copywriting and employer branding roles. It's plain HTML, CSS and JS with no build step: what's in the folder is what goes live. See `README.md` for the file layout, how to preview, the launch checklist and the domain setup.

## Working on it

- **Preview:** from this folder, run `python3 -m http.server 8796` and open http://localhost:8796. Opening the HTML files directly doesn't work, because paths start at `/`.
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

1. **Hero:** the intro animation, then a card stack that follows the mouse, with the headline "Making brands / matter through / [Content | Social Media | Strategy | Websites]." and a "Get in touch" button.
2. **Services:** four stacked colour cards (Content, Social Media, Strategy, Website) that slow down and stack as you scroll, each with a work reel video.
3. **Introduction:** a big statement on the off-white band, revealed row by row on scroll.
4. **Logo wave:** the tools Linn works with (logos in `assets/img/tools/`), on white round badges riding a sine wave, still on the off-white band. Scrolling pushes the row along and the wave swells with speed, after the Osmo "wavy marquee" (measured frame by frame; the constants are in `createLogoWave` in `main.js`).
5. **Stats:** numbers count up when they come into view. **The heading, labels and numbers are placeholders.**
6. **About teaser and contact:** **placeholders** (email, LinkedIn, `assets/cv.pdf`).

The "Selected work" section (case cards and filter) is removed for now; it's in git history before commit `3b4b232`. The case pages in `work/` still exist but have placeholder content.

## Decisions to keep

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
