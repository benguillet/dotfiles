---
name: top-builders-in-france
description: Find the top Paxel builders located in a region (default France, with a Paris / Île-de-France breakout), ranked by builder score, with percentile context against all Paxel users, explicit location provenance, and an optional cross-reference against a YC event invite list (e.g. Startup School Paris). Use when asked to find/rank Paxel builders by geography, build a regional outreach/invite shortlist, or check who from a region is already invited to a YC event.
---

# Top builders in France (geo-targeted Paxel builder ranking)

Produces a ranked, location-attributed list of the strongest Paxel builders in a
country/city, with percentile context and (optionally) who is already invited to a
named YC event. Built for outreach like "special invitations to Startup School Paris."

Default target = **France**, with a **Paris / full Île-de-France** sub-list. The same
process generalizes to any country/city — see "Generalizing" at the end.

## Data sources (all local / via ycli — no app code)

1. **Paxel production copy** (builders + scores), local Postgres:
   `PGPASSWORD=postgres psql -h localhost -p 5434 -U postgres -d paxel_analytics`
   (~5k users / ~10k uploads / ~3.6k scored builders as of mid-2026). If this DB is
   absent, fall back to `bin/db-export --to-dev` freshness or the smaller local
   `paxel_export` DB — but state the row counts so the user knows the coverage.
2. **YC internal DB** (authoritative location), via `ycli tool select-query`.
   Run `ycli skill yc-founders` once for schema context.
3. **YC event invites** (optional cross-ref): `meetups` + `meetup_rsvps` tables in the
   YC DB.

Location is **not stored in Paxel** — it must be joined in from YC `users.latest_location`.

## Process

Work in a scratch dir (default `/tmp`). The bundled scripts in `scripts/` implement
each step; run them in order. **Heads up:** the harness shell often has `noclobber`
set — create files with the Write tool, not `cat > file`.

### 1. Rank all builders by score
Best `v3_results->'overall'->>'score'` per user (0–10). This scans large jsonb
(3–35MB/row) so it takes 1–2 min — run once, cache to TSV. Never `SELECT v3_results`
across all rows; project the scalar only.
```bash
PGPASSWORD=postgres psql -h localhost -p 5434 -U postgres -d paxel_analytics \
  -tA -F $'\t' -o /tmp/paxel_builders.tsv -f scripts/rank_builders.sql
```
Output: `/tmp/paxel_builders.tsv` = `email\tscore`, one row per builder, score-desc.

### 2. Resolve authoritative location (YC join)
Match each builder email → YC `users.latest_location` (free-text like "Paris, France").
~2/3 of builders match. **`ycli tool select-query` chokes on large IN lists — batch ≤120 emails.**
`positions`/`companies` location columns and `apps.demo_*` are sparse/"Unknown" — only
`latest_location` is reliable.
```bash
python3 scripts/yc_locations.py   # reads paxel_builders.tsv -> writes /tmp/yc_locations.tsv
```

### 3. Catch France builders NOT in YC's user table — WEB-VERIFY each (DO NOT SKIP)
The YC join misses ~1/3 of builders — anyone who used a different email or never applied
to YC (in the original run this included the #1 overall builder, and Stanislas Girard /
Quivr who only surfaced via **GitHub**). These would be silently dropped without this step,
so it is **mandatory whenever the qualifying pool could change the answer** (i.e. any
unmatched builder scores above your cutoff).

First narrow to plausible candidates — unmatched high-scorers with a French/European signal
(`.fr`/European domain, working timezone +01:00/+02:00 from
`builder_profile_data->'inferred_timezone'`, or a French given-name handle):
```bash
python3 scripts/timezones.py      # pulls inferred_timezone for unmatched>=7.0
python3 scripts/fr_candidates.py  # writes /tmp/fr_candidates.json
```
Then **web-verify every candidate individually** with the **Workflow** tool using
`scripts/verify_workflow.js` (one agent per person, locate → adversarial France verify,
structured output). Each agent uses WebSearch + WebFetch to check, in priority order:
1. **LinkedIn** — the `location` field (the single most reliable signal) + current employer.
2. **GitHub** — the profile `location` field + company (how Stan Girard/Quivr was caught).
3. **Company website** — "based in" / team page for the email's domain.
4. **Crunchbase / X / personal site** — corroboration.

It distinguishes a person's CURRENT residence from their company HQ (a Paris-brand startup
can have a California founder — caught Palmier this way). **Two traps the verify step must
guard:** CET/CEST covers Germany/Spain/Italy/UK-summer/Ireland/Portugal/Nordics —
*not just France* (it correctly rejected London/Lisbon/Milan/SF builders); and a French name
≠ French residence. Default to NOT-France on weak/conflicting evidence; require a real
current-residence source to confirm.

Save the confirmed-France results to `/tmp/fr_verified.json`
(`[{"email","name","city","source","linkedin"}]`, where `source` is the exact field that
pinned them, e.g. `GitHub StanGirard location = "Paris"`). `analyze.py` folds them into the
ranking and shows that provenance verbatim in the `location_pinned_from` column.

### 4. Percentiles + region classification + provenance + CSV
Computes p50/p90/p95/p99 over best-score-per-builder, each French person's "top X%",
Île-de-France membership (depts 75/77/78/91/92/93/94/95), and an explicit
`location_pinned_from` string (verbatim `users.latest_location` value, or the web field
for non-YC builders). Writes the two CSVs.
```bash
python3 scripts/analyze.py
# -> /tmp/paxel_top10_france.csv  and  /tmp/paxel_paris_ile_de_france.csv
```

### 5. (Optional) Cross-reference a YC event invite list
Find the event in `meetups` (by `title`/`city`/`slug`), then classify each builder via
`meetup_rsvps` joined to YC `users`. Invite semantics:
- **invited** = `invited_at` set → status `confirmed` / `invite_pending` / `invite_expired` / `declined`
- **applied** = self-applied, no invite yet → `applied` / `*_waitlist`
- **not in list** = no RSVP row at all (the proactive-invite targets)

Always grep the raw RSVP dump for surnames of "not in list" people to catch alternate-email RSVPs.
```bash
# find the event id:
ycli tool select-query --limit 60 --query "SELECT id,slug,title,city,starts_at,capacity FROM meetups WHERE title ILIKE '%<event>%' OR city ILIKE '%<city>%' ORDER BY starts_at DESC NULLS LAST"
# then dump RSVPs + cross-ref:
python3 scripts/xref_event.py <meetup_id>   # adds sus_paris_status-style column to the CSVs
```

## Output / deliverables
- **Score distribution** (p50/p90/p95/p99, mean, max) over all scored builders.
- **Top-N in France** table: rank, score, top-X%, name, city, email, LinkedIn, location source + exact value.
- **Paris / full Île-de-France** table (ranked).
- (If requested) **event-invite status** column + an "invite these" shortlist (not-in-list + applied, highest score first).

## Calibration notes (from the original run, 2026-06)
- Score distribution: p50≈6.75, p90≈7.56, p95≈7.77, p99≈8.11, max 9.55. The best French
  builder historically sat ~top 2% (7.98) — strong but the global top (9.5+) was not French.
- "France" builders ≈ 50 of 3.6k; Paris/IDF ≈ 27. So a "top 10 France" is a real top-10,
  but be honest if the qualifying pool is smaller than N.
- Surface useful negatives explicitly (e.g. a Paris-brand company whose founder lives in
  California; a French-named builder who lives in London/Lisbon/Milan).
- Note the residual blind spot: a French builder with an opaque email handle AND no
  timezone signal can't be caught by heuristics and may be missed.

## Generalizing to another region
- Country: change the `ILIKE '%france%'` filter in `analyze.py` and the name/domain/timezone
  heuristics in `fr_candidates.py` (timezone offset, ccTLD, common given-names list).
- City/metro: replace the Île-de-France department/city set in `analyze.py`.
- Different event: pass a different `meetup_id` to `xref_event.py`.
