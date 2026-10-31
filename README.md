# Portfolio

A personal portfolio for content, social media, PR, copywriting and employer branding roles. It's plain HTML, CSS and a little JavaScript, with no build step: what's in this folder is exactly what goes live. It's hosted on GitHub Pages.

## Structure

```
index.html                 home: hero, filterable work, capabilities, about, contact
work/<case>/index.html     one folder per case, so the URL is /work/<case>/
about/index.html
404.html
assets/css/style.css       design tokens at the top, in :root
assets/js/main.js          discipline filter, footer year
assets/img/<case>/         images per case
assets/cv.pdf
robots.txt
```

Paths start with `/` (for example `/assets/css/style.css`). This works on `<username>.github.io` and on a custom domain. Opening a file directly from Finder doesn't work, so use a local server instead (see below).

## Preview locally

From this folder, run:

```bash
python3 -m http.server 8796
```

Then open http://localhost:8796.

## Add a case

1. Copy a folder in `work/`, for example `work/nilar/`, and give it a new name. The name becomes the URL.
2. Edit the text, then put the images in `assets/img/<case>/`.
3. Add a card to the case list in `index.html`.
4. Update the "Next case" links so the cases still go round in a loop.

## Discipline filter

Each case card in `index.html` has a `data-tags` attribute with the filters it belongs to, separated by spaces:

| Key | Chip |
| --- | --- |
| `content` | Content |
| `social` | Social media |
| `pr` | PR and comms |
| `copy` | Copywriting |
| `employer-branding` | Employer branding |
| `coordination` | Campaign coordination |

You can link to a filtered list, for example `/?tag=social#work`.

## Videos

The work reels in the hero cards and service cards are in `assets/video/`. Each is a 960×540 H.264 file at about 1.5 Mbps, with no sound, plus a poster still. They are muted, looping and inline, so they autoplay everywhere. They only load and play near the screen. On phones only the front hero card plays.

To add or replace a reel, compress it first. This Mac has no ffmpeg, so use the Swift transcoder in `tools/`:

```bash
swiftc -O tools/transcode.swift -o /tmp/transcode
/tmp/transcode "in.mp4" assets/video/name.mp4 assets/video/name.jpg 960 540 1500000
```

## Handwritten logo

`assets/img/linn-logo-write.svg` is generated from the logo. If the logo changes:

1. Render it at 1192×674.
2. Run `tools/skeleton.py`, which traces the pen path.
3. Run `tools/build_write.py`, which fixes up coverage, times the left-to-right sweep and writes the SVG.

`tools/coverage.py` draws a check image.

## Before launch

- Remove `<meta name="robots" content="noindex">` from every page.
- In `robots.txt`, change `Disallow: /` to `Allow: /`.
- Add `sitemap.xml` with the real URLs, and a `Sitemap:` line in `robots.txt`.
- Add Open Graph tags, `og-image.jpg` and a favicon.
- Replace every placeholder: name, email, LinkedIn, `assets/cv.pdf`.
- **Font licence.** The site uses PP Mori by Pangram Pangram. The files in `assets/fonts/` are the free personal-use version. That version can't be used on a public website or uploaded online, so the folder is kept out of git. Before launch:
  1. Buy a web licence at pangrampangram.com.
  2. Put the licensed `.woff2` files in `assets/fonts/` and point the `@font-face` rules in `style.css` at them.
  3. Remove `assets/fonts/` from `.gitignore`.

## Publish

The repo is `<username>.github.io`. In its settings, Pages is set to deploy from the `main` branch, root folder. Every push to `main` goes live within a minute or two.

## Custom domain (later)

1. Buy the domain.
2. Add DNS records at the registrar:
   - Four `A` records for the root domain: `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
   - A `CNAME` for `www` pointing to `<username>.github.io`
3. Add a `CNAME` file to this folder that contains only the domain.
4. In the repo's Pages settings:
   - Enter the domain.
   - Verify it under your account's Pages settings.
   - Tick **Enforce HTTPS** once the certificate is ready.
