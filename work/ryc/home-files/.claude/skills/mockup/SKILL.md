---
name: mockup
description: >-
  Create high-fidelity UI mockups: self-contained HTML matched to the target app's real
  design tokens, published to a dedicated claude.ai/design project, screenshotted with
  headless Chrome. Use when the user asks to "make mockups", "mock up this UI", "design
  the states for X", or when another skill (e.g. /draft-spec) needs mockups because the
  work involves new or changed user-facing UI/UX. Returns embeddable artifacts: screenshot
  PNGs plus one design-project link.
---

# Create UI Mockups

Build mockups that look like the real product, publish them where teammates can browse
them (claude.ai/design), and produce screenshots a doc can embed. The deliverable is
always: **PNG screenshots + one claude.ai/design project link**.

## 1. Match the real product — never invent a style

- Pull the target app's **actual** design tokens from its code: font (stylesheets /
  tailwind config), page background, card/border styles, button and checkbox styles,
  brand accent colors. Read the real components; if the feature builds on an existing
  screen or an open MR, match it exactly (a user-provided screenshot is a good reference,
  but confirm tokens in code — e.g. a checkbox that screenshots black may really be
  `accent-orange-600`).
- Write **self-contained HTML files with hand-written CSS** (a shared `_shared.css` in the
  same directory is fine). Load fonts via a Google Fonts link. Avoid CDN frameworks
  (Tailwind CDN etc.) — sandboxed previews may not load them.
- One file per state/screen, numbered (`01-<state>.html`, …), plus a `00-overview.html`
  stacking every state with small uppercase captions.
- First line of every file: `<!-- @dsCard group="<Feature>" -->` so claude.ai/design
  renders preview cards.
- Build in a scratch/gitignored directory (e.g. `.context/design/<feature>/`).

## 2. Publish to claude.ai/design (DesignSync tool)

- `list_projects`, then `create_project` for a **dedicated per-feature project** named
  like "App — Feature (what it shows)". Never push feature mockups into a shared org
  design-system project.
- `finalize_plan` (writes globs + `localDir` = the mockup directory, `deletes: []`), then
  `write_files` with `localPath` entries.
- The shareable link is `https://claude.ai/design/<projectId>`.

## 3. Screenshot with headless Chrome

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=2 --virtual-time-budget=8000 \
  --window-size=800,<height> --screenshot=<out>.png "file://<mockup>.html"
```

- `--virtual-time-budget` is required or web fonts won't load before capture. **Verify by
  reading each PNG** that the real font rendered (the Helvetica fallback is easy to spot)
  and nothing is clipped; re-shoot if not.
- Save PNGs next to the consuming doc (e.g. `docs/specs/images/<feature>-<state>.png`).

## 4. Hand back and embed minimally

Report: the PNG paths, the design-project link, and the mockup source directory.

When the caller embeds results in a doc: each screenshot inline where that state is
discussed, plus the **single** project link — nothing else. No meta-verbiage: no canvas or
file names, no source paths, no visual-language notes ("matches Outfit, gray-200 card…").
The screenshots show the visuals; the doc needs only the images and one link.
