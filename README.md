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

## Before launch

- Remove `<meta name="robots" content="noindex">` from every page.
- In `robots.txt`, change `Disallow: /` to `Allow: /`.
- Add `sitemap.xml` with the real URLs, and a `Sitemap:` line in `robots.txt`.
- Add Open Graph tags, `og-image.jpg` and a favicon.
- Replace every placeholder: name, email, LinkedIn, `assets/cv.pdf`.

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
