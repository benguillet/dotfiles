#!/usr/bin/env python3
"""Build the sprint-demos ship-log HTML report from a JSON config.

Usage: deck-builder.py <config.json>

Config shape (all HTML strings may contain inline markup; code terms in <code>):
{
  "out": "/tmp/sprint-demos/report.html",
  "embed_shots": true,              // false -> skip screenshots entirely (artifact variant)
  "shots_dir": "/tmp/sprint-demos/shots",
  "week_label": "WEEK OF JUN 24, 2026",
  "title": "Five things I shipped this week",
  "subtitle": "A quick, clickable tour ...",
  "byline": "Ben Guillet · App Ops · yc-software",
  "stats": [["5", "features shipped"], ...],
  "features": [
    {
      "num": "01", "id": "f1",
      "nav": "Paxel YC SSO",
      "title": "“Sign in with Y Combinator” on Paxel",
      "summary": "One-two sentence gray summary under the title.",
      "badges": [
        {"type": "live",    "text": "Live in prod"},          // green dot pill
        {"type": "launch",  "text": "Launched to everyone · Jun 12"},  // orange dot pill
        {"type": "local",   "text": "Local demo · addis-ababa"},  // amber pill
        {"type": "review",  "text": "In review · branch ..."},    // amber pill
        {"type": "mr",      "text": "MR !52164", "href": "..."},   // blue link pill
        {"type": "plain",   "text": "inert by default"}        // gray outline pill
      ],
      "why": "<p>...</p><p>...</p>",
      "built": "<p>...</p>",
      "tryit": "<b>Try it →</b> click <a href=...>this link</a> and ...",  // optional
      "demo": {                                                  // optional right card
        "label": "LIVE DEMO",                                   // uppercase card header
        "buttons": [{"text": "Open →", "href": "..."}],
        "shots": [["file.png", "caption"], ...],                // from shots_dir
        "note": "small gray note under the shots"               // optional
      },
      "analytics": {                                             // optional, launched features
        "label": "SINCE LAUNCH · JUN 12",                       // uppercase card header
        "stats": [["340", "founders used it"], ...],            // 2-4 stat chips
        "bullets": ["<b>Before/after:</b> ... with <code>terms</code>", ...],  // optional
        "note": "Window Jun 12-24; staff excluded; source: prod DB"  // optional fine print
      },
      "how": ["<b>Lead-in:</b> bullet body with <code>terms</code>", ...]  // optional
    }
  ],
  "also": ["<b>etl !504</b> — one-liner", ...],
  "footer": "Built by Ben Guillet · Week of ... · Screenshots are live captures ..."
}
"""
import base64, html, json, pathlib, sys

cfg = json.loads(pathlib.Path(sys.argv[1]).read_text())
shots_dir = pathlib.Path(cfg.get("shots_dir", "."))
embed = cfg.get("embed_shots", True)

CSS = """
  :root { --bg:#f7f6f3; --card:#ffffff; --line:#e8e5df; --ink:#1a1a1a; --ship-body:#4b4a47;
          --dim:#8a8680; --orange:#e8590c; --orange-soft:#fdf0e6;
          --green:#1f7a3d; --green-soft:#e9f6ee; --amber:#b45309; --amber-soft:#fdf3e0;
          --blue:#1d4ed8; --blue-soft:#e9effd; }
  * { box-sizing:border-box; }
  html { scroll-behavior:smooth; }
  body { margin:0; background:var(--bg); color:var(--ship-body);
         font:15px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; }
  .wrap { max-width:1020px; margin:0 auto; padding:0 28px; }
  header.hero { padding:56px 0 28px; }
  .kicker { display:inline-flex; align-items:center; gap:8px; background:var(--orange-soft);
            color:var(--orange); font-size:11.5px; font-weight:700; letter-spacing:.12em;
            text-transform:uppercase; padding:6px 12px; border-radius:999px; }
  .kicker::before { content:""; width:7px; height:7px; border-radius:50%; background:var(--orange); }
  h1 { color:var(--ink); font-size:clamp(30px,4.5vw,42px); letter-spacing:-.02em;
       margin:16px 0 10px; line-height:1.15; }
  .sub { max-width:64ch; margin:0 0 14px; color:var(--ship-body); font-size:16px; }
  .byline { color:var(--dim); font-size:13.5px; }
  nav.toc { position:sticky; top:0; z-index:10; background:rgba(247,246,243,.93);
            backdrop-filter:blur(6px); border-top:1px solid var(--line);
            border-bottom:1px solid var(--line); }
  nav.toc .wrap { display:flex; flex-wrap:wrap; gap:4px 26px; padding:11px 28px; }
  nav.toc a { text-decoration:none; font-size:13px; color:var(--ink); }
  nav.toc a b { color:var(--orange); font-weight:700; margin-right:6px; }
  .stats { display:grid; grid-template-columns:repeat(auto-fit,minmax(170px,1fr));
           gap:16px; margin:30px 0 8px; }
  .stat { background:var(--card); border:1px solid var(--line); border-radius:12px;
          padding:16px 18px; box-shadow:0 1px 2px rgba(0,0,0,.04); }
  .stat b { display:block; color:var(--ink); font-size:26px; font-weight:700; }
  .stat span { color:var(--dim); font-size:12.5px; }
  section.feature { padding:44px 0 8px; }
  .fhead { display:flex; align-items:baseline; gap:14px; }
  .fnum { flex:none; background:var(--orange); color:#fff; font-weight:800; font-size:14px;
          width:32px; height:32px; border-radius:9px; display:inline-flex;
          align-items:center; justify-content:center; transform:translateY(5px); }
  .fhead h2 { color:var(--ink); font-size:24px; letter-spacing:-.01em; margin:0; }
  .fsum { margin:10px 0 12px 46px; max-width:78ch; color:#4b4a47; }
  .badges { display:flex; flex-wrap:wrap; gap:8px; margin:0 0 20px 46px; }
  .pill { display:inline-flex; align-items:center; gap:6px; font-size:12px; font-weight:600;
          padding:4px 11px; border-radius:999px; border:1px solid transparent; text-decoration:none; }
  .pill.live { color:var(--green); background:var(--green-soft); }
  .pill.live::before { content:""; width:6px; height:6px; border-radius:50%; background:var(--green); }
  .pill.launch { color:var(--orange); background:var(--orange-soft); }
  .pill.launch::before { content:""; width:6px; height:6px; border-radius:50%; background:var(--orange); }
  .pill.local, .pill.review { color:var(--amber); background:var(--amber-soft); }
  .pill.mr { color:var(--blue); background:var(--blue-soft); }
  .pill.plain { color:var(--dim); background:transparent; border-color:var(--line); }
  .cols { display:grid; grid-template-columns:1fr 1fr; gap:18px; align-items:start; }
  @media (max-width:860px) { .cols { grid-template-columns:1fr; } }
  .card { background:var(--card); color:#4b4a47; border:1px solid var(--line); border-radius:12px;
          padding:20px 22px; box-shadow:0 1px 2px rgba(0,0,0,.04); }
  .card + .card, .cols + .card { margin-top:18px; }
  .chead { color:var(--dim); font-size:11px; font-weight:700; letter-spacing:.09em;
           text-transform:uppercase; margin:0 0 12px; }
  .card h4.chead2 { color:var(--dim); font-size:11px; font-weight:700; letter-spacing:.09em;
           text-transform:uppercase; margin:20px 0 8px; }
  .card p { margin:0 0 10px; color:#4b4a47; font-size:13.5px; }
  .card b, .card strong { color:var(--ink); }
  code { font:12px ui-monospace, SFMono-Regular, Menlo, monospace; color:var(--ink);
         background:#f1efeb; padding:1px 5px; border-radius:5px; }
  .tryit { border-left:3px solid var(--orange); background:#fffaf5; color:#4b4a47; border-radius:0 8px 8px 0;
           padding:10px 14px; font-size:13px; margin-top:14px; }
  .tryit b { color:var(--orange); }
  .tryit a { color:var(--blue); }
  .demo-buttons { display:flex; flex-wrap:wrap; gap:10px; margin:0 0 14px; }
  .demo-buttons a { background:var(--orange); color:#fff; font-weight:700; font-size:13px;
                    text-decoration:none; padding:8px 16px; border-radius:8px; }
  .demo-buttons a.alt { background:transparent; color:var(--ink); border:1px solid var(--line); }
  figure.shot { margin:0 0 14px; }
  figure.shot img { width:100%; display:block; border:1px solid var(--line); border-radius:8px; }
  figure.shot figcaption { color:var(--dim); font-size:12px; margin-top:6px; }
  .demo-note { color:var(--dim); font-size:12px; }
  .how ul { margin:0; padding-left:18px; }
  .how li { color:#4b4a47; font-size:13.5px; margin:0 0 9px; }
  .analytics .astats { display:grid; grid-template-columns:repeat(auto-fit,minmax(150px,1fr));
                       gap:12px; margin:0 0 12px; }
  .analytics .astats .stat { padding:12px 14px; }
  .analytics .astats .stat b { font-size:20px; }
  .analytics ul { margin:0 0 10px; padding-left:18px; }
  .analytics li { color:#4b4a47; font-size:13.5px; margin:0 0 8px; }
  section.also { padding:44px 0 10px; }
  section.also h2 { color:var(--ink); font-size:22px; margin:0 0 6px; }
  .also ul { list-style:none; margin:14px 0 0; padding:0; }
  .also li { color:#4b4a47; padding:9px 0; border-bottom:1px solid var(--line); font-size:13.5px; }
  footer { border-top:1px solid var(--line); margin-top:44px; padding:22px 0 40px;
           color:var(--dim); font-size:12.5px; text-align:center; }
"""

def esc(s): return html.escape(s, quote=True)

def shot_html(name, caption):
    if not embed:
        return ""
    p = shots_dir / name
    if not p.exists():
        return ""
    b64 = base64.b64encode(p.read_bytes()).decode()
    return (f'<figure class="shot"><img src="data:image/png;base64,{b64}" alt="{esc(caption)}">'
            f'<figcaption>{esc(caption)}</figcaption></figure>')

def badge_html(b):
    t = b.get("type", "plain")
    inner = esc(b["text"])
    if b.get("href"):
        return f'<a class="pill {t}" href="{esc(b["href"])}">{inner}</a>'
    return f'<span class="pill {t}">{inner}</span>'

def feature_html(f):
    badges = "".join(badge_html(b) for b in f.get("badges", []))
    left = f'<div class="card"><p class="chead">Why</p>{f["why"]}'
    left += f'<h4 class="chead2">What I built</h4>{f["built"]}'
    if f.get("tryit"):
        left += f'<div class="tryit">{f["tryit"]}</div>'
    left += "</div>"

    demo = f.get("demo")
    right = ""
    if demo:
        right = f'<div class="card"><p class="chead">{esc(demo.get("label", "Live demo"))}</p>'
        btns = demo.get("buttons", [])
        if btns:
            right += '<div class="demo-buttons">' + "".join(
                f'<a{"" if i == 0 else " class=\"alt\""} href="{esc(b["href"])}">{esc(b["text"])}</a>'
                for i, b in enumerate(btns)) + "</div>"
        for name, cap in demo.get("shots", []):
            right += shot_html(name, cap)
        if demo.get("note"):
            right += f'<p class="demo-note">{demo["note"]}</p>'
        right += "</div>"

    body = f'<div class="cols">{left}{right}</div>' if right else left
    analytics = ""
    a = f.get("analytics")
    if a:
        analytics = f'<div class="card analytics"><p class="chead">{esc(a.get("label", "Since launch"))}</p>'
        chips = a.get("stats", [])
        if chips:
            analytics += ('<div class="astats">'
                          + "".join(f'<div class="stat"><b>{esc(n)}</b><span>{esc(l)}</span></div>'
                                    for n, l in chips) + "</div>")
        if a.get("bullets"):
            analytics += "<ul>" + "".join(f"<li>{b}</li>" for b in a["bullets"]) + "</ul>"
        if a.get("note"):
            analytics += f'<p class="demo-note">{a["note"]}</p>'
        analytics += "</div>"
    how = ""
    if f.get("how"):
        how = ('<div class="card how"><p class="chead">How it works</p><ul>'
               + "".join(f"<li>{h}</li>" for h in f["how"]) + "</ul></div>")

    return (f'<section class="feature" id="{f["id"]}"><div class="wrap">'
            f'<div class="fhead"><span class="fnum">{f["num"]}</span><h2>{f["title"]}</h2></div>'
            f'<p class="fsum">{f["summary"]}</p>'
            f'<div class="badges">{badges}</div>{body}{analytics}{how}</div></section>')

nav = "".join(f'<a href="#{f["id"]}"><b>{f["num"]}</b>{esc(f["nav"])}</a>' for f in cfg["features"])
stats = "".join(f'<div class="stat"><b>{esc(n)}</b><span>{esc(l)}</span></div>' for n, l in cfg["stats"])
features = "".join(feature_html(f) for f in cfg["features"])
also = "".join(f"<li>{a}</li>" for a in cfg.get("also", []))

page = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(cfg["title"])} — {esc(cfg["week_label"].title())}</title>
<style>{CSS}</style></head><body>
<header class="hero"><div class="wrap">
  <span class="kicker">Ship log · {esc(cfg["week_label"])}</span>
  <h1>{esc(cfg["title"])}</h1>
  <p class="sub">{cfg["subtitle"]}</p>
  <p class="byline">{esc(cfg["byline"])}</p>
</div></header>
<nav class="toc"><div class="wrap">{nav}</div></nav>
<div class="wrap"><div class="stats">{stats}</div></div>
{features}
<section class="also"><div class="wrap"><h2>Also shipped</h2><ul>{also}</ul></div></section>
<footer><div class="wrap">{cfg["footer"]}</div></footer>
</body></html>"""

out = pathlib.Path(cfg["out"])
out.write_text(page)
print(f"wrote {out} ({out.stat().st_size/1024:.0f} KB)")
