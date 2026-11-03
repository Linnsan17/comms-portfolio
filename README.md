# Portfolio

A personal portfolio for content, social media, PR, copywriting and employer branding roles. It's one page of plain HTML, CSS and JavaScript, with no build step: what's in this folder is exactly what goes live. It's hosted on GitHub Pages.

## Structure

```
index.html                 the whole site: hero, services, introduction, toolbox, selected work, footer
404.html                   shown for any address that doesn't exist
assets/css/style.css       design tokens at the top, in :root
assets/js/main.js          all the motion and interaction
assets/img/                logo, portrait, hero cut-out, tool logos, work stills
assets/video/              compressed videos (see Videos)
assets/cv.pdf              exported from cv/ (see CV)
cv/                        Linn's CV as a page: one A4 sheet, and the script that exports the PDF
robots.txt
```

Paths start with `/` (for example `/assets/css/style.css`). This works on `<username>.github.io` and on a custom domain. Opening a file directly from Finder doesn't work, so use a local server instead (see below).

## Preview locally

From this folder, run:

```bash
python3 tools/serve.py
```

Then open http://localhost:8796. The script turns browser caching off for pages, styles and scripts, so a reload always shows the latest CSS and JS (with `python3 -m http.server` a reload can mix new HTML with an old stylesheet and look broken). It also answers byte-range requests, as GitHub Pages does, so the videos load in pieces and play and loop smoothly; restart it after pulling a new `serve.py`.

## Set up on a new computer

1. **Get access.** The repo `Linnsan17/comms-portfolio` is private, so the owner first adds you as a collaborator on GitHub: Settings → Collaborators → Add people.
2. **Clone.** Install GitHub Desktop, sign in, then choose File → Clone repository → `Linnsan17/comms-portfolio`.
3. **Add the fonts.** PP Mori isn't in git (licence), so put your own copy of the free personal-use files in `assets/fonts/`. `CLAUDE.md` lists the exact file names.
4. **Preview** as described above.

`CLAUDE.md` has the project's decisions, specs and what's still placeholder content. Claude Code reads it automatically.

Before you start, pull the latest changes (Fetch origin, then Pull, in GitHub Desktop). When you're done, push. That way you don't overwrite each other's work.

## Add a case

The cases live on the home page; there are no case pages.

1. In `index.html`, copy one `<article class="area">` in the Selected work section.
2. Change the title, its `id`, the number, the text and the lists.
3. Cut the case's film to the card's shape (see Videos) and point the `<video>` at it, or use a still in `assets/img/work/`.
4. Fill in the `<template data-sheet-more>` at the end of the article: the story of the work as one text block, and three numbers with their labels (or, to pick out one project with its own title, picture and numbers, a beige `sheet__feature` box like Svedea's). "View case" shows them in the case's sheet, under the card's film, summary and facts.

## Videos

The hero cards behind the phone play footage from Linn's work, edge to edge (`hero-boat`, `hero-dog`, `hero-tree`, `hero-turbines`). Behind the hand on the front card is a still of clouds (`assets/img/hero/hero-clouds.jpg`, the cloud sea at 1.2 s of Nilar's Almedalen film, 1600×900). The service cards play their own films (`service-*`), and a Selected work card plays its case's own film (`case-*`). All are in `assets/video/`. Each is an H.264 file with no sound, plus a poster still: the hero clips are 960×540 at about 1.5 Mbps, the service films 960×640 at 2 Mbps (the service card's 3:2 media box) and the case films 896×752 at 30 fps and about 2 Mbps (the case card's media box; Boneo's, Svedea's and Nilar's are edits, made by `tools/boneo_edit.swift`, `tools/svedea_edit.swift` and `tools/nilar_edit.swift`). `transcode` crops the middle to fit. They are muted, looping and inline, so they autoplay everywhere. Each starts loading a little before it reaches the screen and only plays while it's on screen; in the stacked sections a film also pauses once the next card hides most of it, so the browser never decodes more films than you can see. On phones only the front hero card plays.

To add or replace a reel, compress it first. This Mac has no ffmpeg, so use the Swift transcoder in `tools/`:

```bash
swiftc -O tools/transcode.swift -o /tmp/transcode
/tmp/transcode "in.mp4" assets/video/name.mp4 assets/video/name.jpg 960 540 1500000
```

Svedea's case film is an edit rather than a straight cut (two shots taken out, an employer branding shot of three images put in): `tools/svedea_edit.swift` makes it from Svedea's reel, the three images, the dog-puzzle clip for the phone's screen (its corners in every frame from `tools/phone_track.swift` and `tools/phone_screen.py`) (usage at the top of each file). Boneo's is one too (two Instagram posts slide past where two Facebook ads did): `tools/boneo_edit.swift` makes it from Boneo's reel and the two posts. Both keep the reel's colours exactly; compile them with `swiftc -O` like the transcoder.

Add a start and a length in seconds to keep only part of a clip, for example `... 960 540 1500000 19.56 2.92`. Add `bounce` after them to play that part forward and then backward, so a short clip loops without a jump. For a portrait clip, keep its own shape (for example `720 960`) and aim the crop with `object-position` on the video.

## Hero phone

The front hero card shows a hand holding a phone that plays `assets/video/hero-phone-boneo.mp4` (Boneo's campaign ad, `boneo_kampanj.mp4`, all 7 seconds at 360×640), warped onto the phone's screen by `main.js`. To show another video, replace that file and its poster; any 9:16 video works, and the sides are cropped slightly to fit the screen.

An earlier version, with Linn's portrait on the screen and her name in pink letters that drop in with physics, is saved on the branch `phone-letters`.

The hand and phone are cut out of the hero photo (`assets/img/hero/phone-hand.webp`), with a hole for the screen. To redo the cut-out:

1. Lift the subject with macOS Vision. This writes the cut-out and `photo-mask.png`:

   ```bash
   swiftc -O tools/lift.swift -o /tmp/lift
   /tmp/lift photo.png photo.png
   ```

2. Clean the edges, cut the screen hole and get the screen's corners:

   ```bash
   python3 tools/phone_cutout.py photo.png photo-mask.png assets/img/hero/phone-hand.webp
   ```

   It prints `PHONE_SCREEN`; paste the value into `main.js`.

## Tool logos

The logo wave after the introduction shows the tools in `assets/img/tools/`. To add one:

1. Save the logo as a trimmed `.webp` about 320px on its longest side, or as an `.svg`.
2. Copy one of the `<li class="logo-wave__item">` lines in `index.html` and change the image and its `alt`.
3. Set `--w` to the logo's width as a share of the badge. The default, 0.36, suits a square icon; a wide wordmark needs more (Canva is 0.56).

The script repeats the badges to fill the screen, so any number of logos works. "View all" lists the same logos with their names (taken from each `alt`) in a sheet, so there's nothing else to update.

## Handwritten logo

`assets/img/linn-logo-write.svg` is generated from the logo. If the logo changes:

1. Render it at 1192×674.
2. Run `tools/skeleton.py`, which traces the pen path.
3. Run `tools/build_write.py`, which fixes up coverage, times the left-to-right sweep and writes the SVG.

`tools/coverage.py` draws a check image.

## CV

`cv/index.html` is Linn's CV, translated from her Swedish CV, laid out as one A4 page (`cv/cv.css`). With the preview running it's at http://localhost:8796/cv/. "Download CV" on the site links to `assets/cv.pdf`, which is exported from that page:

```bash
swiftc -O cv/export_pdf.swift -o /tmp/export_pdf
/tmp/export_pdf http://localhost:8796/cv/ assets/cv.pdf
```

It uses WebKit, because Chrome's "Save as PDF" turns PP Mori into outlines and the text then copies out broken. If an edit makes the text run past the bottom margin, the script stops and says by how much. The PDF embeds PP Mori, so it falls under the font licence below.

## Before launch

Done: the site is findable (no `noindex` except on the 404 page, `robots.txt` allows everything and points to `sitemap.xml`), has link previews (Open Graph tags and `og-image.jpg`: Linn's portrait and signature on the beige), a favicon (`favicon.svg`, `favicon-32.png`, `apple-touch-icon.png`) and the `CNAME` for linncoms.xyz. Still to do:

- **LinkedIn.** The footer's link goes to linkedin.com, and the CV says `linkedin.com/linnharrvik`. Put Linn's real profile address (`linkedin.com/in/…`) in both, then export the CV again.
- **Font licence.** The site uses PP Mori by Pangram Pangram. The files in `assets/fonts/` are the free personal-use version. That version can't be used on a public website or uploaded online, so the folder is kept out of git, and the live site falls back to a system font until:
  1. A web licence is bought at pangrampangram.com (the CV PDF embeds PP Mori too, so it falls under the same licence).
  2. The licensed `.woff2` files go in `assets/fonts/` and the `@font-face` rules in `style.css` point at them.
  3. `assets/fonts/` comes out of `.gitignore`.
- **A public repository.** Free GitHub Pages only publishes public repositories (or private ones with GitHub Pro). Public means the whole repo and its history can be read, including these notes and earlier CVs.

## Publish

GitHub Pages publishes this repository, `Linnsan17/comms-portfolio`, from the `main` branch, root folder, at the custom domain in `CNAME`: **linncoms.xyz**. With a custom domain the repository doesn't have to be called `<username>.github.io`; the site still sits at the domain's root, so the paths starting with `/` work. Every push to `main` goes live within a minute or two.

## Custom domain: linncoms.xyz

1. **Buy linncoms.xyz** at a registrar (Porkbun or Cloudflare are cheapest to renew). Turn on WHOIS privacy, so Linn's address isn't public.
2. **DNS at the registrar** (on Cloudflare, set the records to "DNS only", the grey cloud):
   - `A` records for the root domain (`@`): `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
   - `AAAA` records for `@`: `2606:50c0:8000::153`, `2606:50c0:8001::153`, `2606:50c0:8002::153`, `2606:50c0:8003::153`
   - `CNAME` for `www`: `linnsan17.github.io`
3. **Verify the domain** on GitHub: github.com/settings/pages, **Add a domain**, enter `linncoms.xyz`, add the `TXT` record it shows at the registrar, then **Verify**. This stops anyone else's GitHub site from claiming the domain.
4. **Turn on Pages:** the repository's **Settings → Pages**, Source **Deploy from a branch**, `main`, `/ (root)`, **Save**. The custom domain field fills in from `CNAME`. When the DNS check passes, tick **Enforce HTTPS** (the certificate can take up to a day).
