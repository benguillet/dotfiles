---
name: appops-tech-spec
description: Write a tech spec / design doc following App Ops's standard template (Background → Goal → Scope → Constraints → Design → Monitoring & Tests → Alternatives). Use when the user asks to "write a tech spec", "draft a design doc", "spec this out", or wants a proposal document for a feature, migration, or refactor.
---

# Tech Spec

Write the spec as a markdown document. Before writing, explore the codebase enough to ground every claim in Background with real file/line references — a spec that asserts behavior without pointing at code is not done. If the user hasn't said where to save it, ask or default to the repo's docs/designs/ (or equivalent) directory.

After saving the markdown file, publish it as a Google Doc and give the user the link (see "Publish to Google Docs" at the end).

## Template

```
# [Feature/Project Name]
[Author]\
[Date]

## Background

## Goal

## Why we need this

## Scope of this doc
### In scope
### Out of scope

## Constraints

## Design
### Overview
### 1..N Numbered components

## Monitoring & Tests
### Monitoring
### Tests

## Alternatives considered
### Alternative 1 — [name]
### Alternative 2 — [name]

## Open questions

## Comments

## Next steps
```

The author line ends with a trailing `\` so the date renders on its own line directly below the author (a CommonMark hard line break). Without it, the two consecutive lines collapse into one paragraph and render side by side in the Google Doc. Do NOT use a blank line between them — that creates a paragraph gap; the date should sit immediately below the author.

## Section rules

**Background** — Current behavior with `path/to/file.rb:123` references for every mechanism described. Cover: what exists today, any existing infrastructure relevant to the change (shadow systems, prior groundwork, half-finished migrations), and the data models / concepts the reader needs. The reader should be able to verify every sentence by opening the cited file.

**Goal** — One paragraph stating the desired end state, including the key invariant the change must preserve (e.g. "must be invisible to users", "zero downtime", "same API contract").

**Why we need this** — Bulleted justifications (quality, cost, risk, velocity). Each bullet must be grounded in data that already exists (a comparison table, metrics, an incident) — not hypotheticals.

**Scope** — Explicit In scope / Out of scope lists. Out of scope is where you prevent scope creep: name the adjacent things you are deliberately NOT changing (other call sites, data model, retirement of old systems).

**Constraints** — Hard rules the design must respect, separated from Design so reviewers can check one against the other: fixed data models, rate limits, async/eventual-consistency behaviors, latency budgets, error-handling conventions. Each constraint should state both the rule and why it exists.

**Design** — Start with a one-paragraph Overview plus an ASCII flow diagram showing the path through the system. Then one numbered section per moving piece (new service/orchestrator, wiring of entry points, data writers, edge-case handling, schema changes). Include code snippets where the shape matters (method signatures, row mappings), not for everything. Each section should say what changes, where it lives, and what it deliberately reuses.

**Monitoring & Tests** — Part of the deliverable, not an afterthought. Monitoring: reused existing instrumentation first, then new metrics (with the dimensions to emit), structured logs, dashboards, and canaries/alerts that would catch the specific regressions this change could cause. Tests: per-component list of cases including failure/fallback paths, plus the exact commands to run before shipping.

**Alternatives considered** — At least one real alternative per major design decision. Each gets a name, a description of how it would work, and an explicit "Rejected: [reason]" tied back to the Goal or Constraints. Alternatives that nobody would actually propose don't count.

**Open questions** — Unresolved design decisions that need a call before or during implementation (data-model choices, naming, ownership, where something lives). Each is a concrete either/or or a specific unknown, not a vague worry — state the options and the tradeoff so a reviewer can answer it. Distinct from Comments: these shape or block the build; Comments is reviewer discussion.

**Comments** — Reviewer discussion threads, attributed by name. Leave this section in even when empty.

**Next steps** — Concrete action items (people to talk to, limits to raise, follow-up work), not a restatement of the design.

## Quality bar

- Every factual claim about current behavior cites a file (and line where useful).
- The invariant in Goal appears again in Design — show how the design preserves it.
- Constraints and Design are checkable against each other; if a design section violates a constraint, the spec is wrong.
- Failure modes (not found, queued, rate-limited, empty, errored) are enumerated explicitly, with the behavior for each — never a generic "handle errors".
- Prefer reusing existing mechanisms (matchers, jobs, comparison tables) over inventing new ones; say so explicitly when you do.
- Rollout safety: if the change swaps a live path, the spec must include a fallback or flag and a way to detect regression without user reports.

## Publish to Google Docs

Once the spec is written and the user is happy with it, create a Google Doc from it using the `gws` CLI (Google Workspace CLI, `brew install googleworkspace-cli`) and give the user the `webViewLink`.

```bash
cd "$(dirname <spec.md>)" && gws drive files create \
  --json '{"name": "<Spec Title>", "mimeType": "application/vnd.google-apps.document"}' \
  --upload "$(basename <spec.md>)" \
  --upload-content-type text/markdown \
  --params '{"fields": "id,webViewLink"}'
```

This uses the Drive API's native markdown import, so headings, bold, lists, tables, and code blocks convert to real Doc formatting. Print the `webViewLink` from the JSON output as a clickable link.

Constraints and failure handling:

- **`--upload` only accepts paths inside the current working directory** — always `cd` to the spec's directory first and pass a bare filename.
- **If `gws` is not installed or not authenticated** (`gws auth status` shows `"credential_source": "none"`), do NOT fail the skill. Deliver the local markdown path as the result and tell the user the one-time setup: `brew install googleworkspace-cli`, then run `! gws auth setup` themselves (interactive browser OAuth; creates the OAuth client) — or `! gws auth login` if already set up. Then offer to retry the publish.
- **403 "insufficient authentication scopes"** has two causes: (a) the Drive checkbox wasn't ticked on Google's consent screen — user must re-run `! gws auth login --services drive,docs` and tick every box; (b) a stale access token — `~/.config/gws/token_cache.json` older than `credentials.enc` means gws is sending a pre-re-consent token; delete the cache file and retry (it regenerates from the refresh token).
- Doc creation is an outward-facing write — only run it after the user has seen the spec content (or explicitly asked for the doc up front). Never publish a half-finished draft.
- If the user revises the spec afterward, create a fresh doc only if asked; otherwise remind them the existing doc won't auto-update (re-publishing creates a new file, it does not update in place).
