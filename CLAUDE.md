# Linn Harrvik portfolio: project notes

A personal portfolio for Linn Harrvik, aimed at in-house content, social media, PR, copywriting and employer branding roles. It's one page of plain HTML, CSS and JS with no build step: what's in the folder is what goes live. See `README.md` for the file layout, how to preview, the launch checklist and the domain setup.

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

1. **Hero:** the intro animation, then a card stack that follows the mouse (the cards behind play footage from Linn's work, edge to edge: boat, dachshund, autumn tree, and at the back wind turbines then a woman in a red hat in the forest (15.6–19.4s of Nilar's Almedalen film, before it cuts to the tree); the front card is a hand holding a phone on the site's pink (`--block-1`, as on the buttons and footer); its screen plays Svedea's dog-puzzle video (`hero-phone-dog`), and the top of the phone pokes out above the card; see README "Hero phone"). The cards are rounded rectangles with 16px corners on screen (main.js scales `--corner` per card), with the headline (black on the beige, turning white exactly where it crosses the cards: main.js clips a white copy to the cards each frame) "Making brands / matter through / [Content | Social Media | Strategy | Websites | Artificial Intelligence (AI on phones) | Marketing]." and a "Get in touch" button.
2. **Services:** the "Services" label and four stacked colour cards (Content, Social Media, Strategy, Website) that slow down and stack as you scroll, each with Linn's own film (`service-content`, `service-social`, `service-strategy`, `service-website`). The label rides with the first card, so the gap between them never changes.
3. **Introduction:** "Introduction", then a big statement on the off-white band, revealed row by row on scroll, and a "Read more" pill that opens the about sheet (the wide portrait, the statement, then a longer story in the body text style: Timrå, her degree and the Njurundaföretagarna identity; Stockholm from 2022; show jumping).
4. **Toolbox:** a hairline (the same `--rule` as the work cards and footer) between "Read more" and the "Toolbox" label, with a "View all" button on the right that opens the toolbox sheet (each tool's logo in a round beige frame, then its name and its number on the right, A to Z, one to a row between hairlines; main.js builds it from the wave's badges, so it always lists the same tools), then the logo wave: the tools Linn works with (logos in `assets/img/tools/`), on white round badges riding a sine wave, still on the off-white band. Scrolling pushes the row along and the wave swells with speed, after the Osmo "wavy marquee" (measured frame by frame; the constants are in `createLogoWave` in `main.js`).
5. **Selected work:** "Selected work", then one full-width card per case: Boneo 01, Svedea 02, Nilar 03, Bilbolaget 04, each with a "View case" button that opens the case's sheet (see Sheets below). Titles in normal case (not caps). Built 1:1 from wearemotto.com's areas of expertise at a 1537px window: as the next card rises, the covered one falls back to 62% of the scroll speed and a dark grey wash builds over it to 60%; the footer slides over the last card the same way. Unlike the reference, the media box is as wide as the footer's last four columns, so it starts where "Ready to talk?" does; it keeps the reference's height, so it's landscape on desktop (portrait on phones). Boneo, Svedea and Nilar play their own films (`case-boneo`, `case-svedea`, `case-nilar`) and Bilbolaget shows its website. The facts under each summary come from Linn's LinkedIn (role, full-time or internship, period; industry, location). **The summaries are drafts** written from the LinkedIn titles and what the films show, for Linn to rewrite in her own voice; there are no results or numbers yet. Each summary gets room for four lines (`min-height: 4em`), so the cards stay the same height; keep summaries to four lines or fewer at 1440.
6. **Footer:** pink, rebuilt 1:1 from the Flow site's footer on a 12-column grid (also on the 404 page): Linn's portrait and "Ready to talk? Get in touch", then Navigate (Services, About, Work: the sections in page order) / Connect (email linnharrvik@gmail.com, which rolls to "Copy email" on hover and copies on click; phone +46 70 398 50 23; LinkedIn) / Open to, then the small print. It carries `#contact`, so every Contact link lands there, and on the home page it slides over the last work card. **Placeholders:** the LinkedIn link and `cv.pdf`; "Open to" is a draft. (The stats, about teaser and get-in-touch sections were removed on 2026-11-01; they're in git history.)

**Sheets:** "View case" and "Read more" open one shared white sheet (`<dialog class="sheet">` at the end of `index.html`) that slides up over the dimmed page, after the project sheets on timestwo.com (48.8% of the window wide, min 640px, full width on phones; 12px from the top; 38px top corners drawn as Apple's continuous curve where the browser supports `corner-shape`, a plain 38px circle elsewhere (only the sheet: the rest of the site keeps its plain corners); it rises from below the screen in 800ms and sinks back in 700ms, both with the site's hard ease in and out (`--roll-ease`); the page dimmed with 40% black). Its header has the title in the middle (`--text-medium`, semibold) and a Close button in the top right corner (a fine X in a round beige button, 44–52px, concentric with the 38px corner the way iOS places it: inset by the corner's radius minus its own), and stays put while the sheet scrolls. Close, Escape, a click on the dimmed page or dragging the header down closes it; the page doesn't move underneath. `main.js` fills the sheet from the card or section around the button (`[data-sheet-source]`): the title (`h3` or `data-sheet-title`), the media (`[data-sheet-media]`, the card's own film or picture, edge to edge in the card's shape), the text (`[data-sheet-intro]`), the fact lists (`[data-sheet-facts]`) and the sheet-only blocks in `<template data-sheet-more>`. In a case sheet those are one text block with no heading (the story of the work, in the service descriptions' style: `--text-medium`, line height 1.3) and three numbers; the about sheet has just a text block, Linn's own. The numbers copy a reference Linn sent: one per row under a hairline, a semibold label on the left and the number at `--text-display` on the right, their capitals level (the reference's numbers are in a monospace with slashed zeros; on 2026-11-01 Linn chose to keep PP Mori rather than add a second font, so don't offer it again). Boneo's sheet has its real story and numbers (its TikTok: 465,400 views on the best post, 56.8× average views, +12,510% average likes); **Svedea's, Nilar's and Bilbolaget's text and numbers are still placeholders** and say so. The numbers all shrink together when the widest would overflow its column (`fitNumbers` in main.js).

**One page:** the about page and the case pages (`about/`, `work/`) were removed on 2026-11-01, along with their styles and the old discipline filter; they're in git history. "About" in the nav and footer goes to the Introduction (`/#introduction`). Only `404.html` is left besides the home page, for addresses that don't exist.

## Decisions to keep

- **Header:** the pink pill is "Download CV" (just "CV" on phones narrower than 383px); it links to `assets/cv.pdf`, which is still to come. The nav is Services, About (the Introduction), Work, Contact, all links within the page.
- **Rounded media:** every photo and video box (service and work cards, footer portrait) has 10px corners (`--radius-media`). The hero cards, which are bigger, have 16px corners on screen.
- **Saved for later:** the phone screen with Linn's portrait and her name in falling pink letters (Matter.js physics), and the hero cards' earlier "pillow" shape, are on the branch `phone-letters`.
- **Section labels:** every section after the hero opens with a semibold label (no brackets) on the left and, where there is one, an underlined link on the right on the same baseline (`.section-head` in `style.css`, after wearemotto.com).

- **Palette ("Geometric" with light blue):**
  - Page background white #ffffff; the warm off-white #f2f0ec behind the hero, the introduction, the toolbox and selected work.
  - Text #1c1c1c.
  - Blocks: pink #fbbad4, rosewood #a45b61, blue #486adc, light blue #bfcef7.
  - Buttons pink. Nav pill white, no outline.
- **Type:** PP Mori everywhere, on a five-size scale (tokens at the top of `style.css`; px at 1440 / on phones):
  - `--text-display` 115 / 56: hero headline, service and case titles. On phones the hero's two fixed rows break onto two lines each so it keeps the display size (56px at 375); phones show "AI" for "Artificial Intelligence".
  - `--text-large` 49 / 28: intro statement, case descriptions, footer.
  - `--text-medium` 23 / 18: service descriptions.
  - `--text-small` 19 / 15: labels, lists, links, buttons, nav, small print.
  - `--text-xsmall` 15 / 14: service lists.

  Use a token for any new text instead of a new size. Buttons and nav are 600 weight. Labels are cap-centred: pills get 0.19em top padding, and every label holder is a flex container.
- **No arrows or icons** on buttons. The one exception is the sheet's Close: an X in a round beige button, as Linn asked.
- **Motion:**
  - **Roll:** `--roll-ease` cubic-bezier(0.76, 0, 0.24, 1) over 620ms, used for the headline word and every button hover (the label rolls down).
  - **Smooth scroll:** Lenis 1.3.26 with lerp 0.1.
  - **Reload:** always starts at the top (scroll restoration off, and the `#section` a nav click leaves in the address is dropped). Arriving from a link to a section still lands there.
  - **Hero intro:**
    - The front card grows from 0 (hard ease), holds, and the rings grow out.
    - The header, logo writing, headline and button appear at the end.
    - The stack stays centred, then follows the mouse 1 second later.
  - **Services stack:** a card slows to 43.6% of scroll speed once its top passes 27% of the viewport.
- **Logo:** `assets/img/linn-logo.svg` is Linn's handwritten signature. `assets/img/linn-logo-write.svg` is a generated version that writes itself in, left to right per line. Regenerate it with the scripts in `tools/` if the logo changes (see README).
- **Videos:** `assets/video/` holds compressed work reels. Add new ones with `tools/transcode.swift` (see README).

## Source material

The original recordings, reference videos, raw work reels and logo files live in a separate working folder ("Linn_portfolio") outside this repo. They aren't needed to build the site; everything the site uses is in `assets/`.
