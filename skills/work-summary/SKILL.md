---
name: work-summary
description: Produce a concise, verified end-of-work handoff report — TL;DR of what shipped, the manual steps left for the human (secrets, env vars), database changes, risks, test/seed/reset scripts, rollback plan, screenshots + bug-bash results for UI work, and all MR/PR links in safe merge order with local test URLs. TRIGGER when the user types /work-summary, or asks to "summarize the work", "what did we ship", "write the handoff", "launch report", or wants a wrap-up of a feature/session before review or merge.
---

# /work-summary — the end-of-work handoff report

One deliverable: an HTML report (from `TEMPLATE.html` in this skill dir) saved to
`docs/specs/<feature-slug>-work-summary.html` (repo-relative, untracked is fine),
`open`ed in the browser, plus a 5-line TLDR in chat. Born from the Paxel
account-state launch report; the sections below are the contract — every one is
addressed, but **empty sections collapse to one line** ("Database: no changes").

**Concision is the product.** The reader is the human who has to merge, deploy,
and un-break this later. Selective beats complete: drop anything that doesn't
change what they'd do next. Hard budget: the report should read in under 3
minutes.

## 1. Gather — from artifacts first, then verify against reality

Mine in this order (cheapest, most-reliable first):
1. Session context + `.context/factory-status.md` (if a factory/scoreboard run
   produced one) + task list — what was built and decided.
2. `git` truth: `git fetch origin`, then for every feature branch:
   `git diff --stat origin/<base>...origin/<branch>` — the diffs define what
   actually shipped (pushed code only; local-only work gets flagged as such).
3. MRs/PRs: `glab mr list`/`glab mr view` and `gh pr list --repo ...` for every
   repo touched. Record: link, title, target branch (stacks!), pipeline status
   (`glab api projects/<p>/merge_requests/<iid>/pipelines?per_page=1`).
4. Artifacts on disk: screenshots (`docs/specs/images/**`), seed/test scripts
   (`tmp/*.rb`, `tmp/*.mjs`), spec/plan docs, prior review outputs.

**Verify, don't trust memory**: pipeline states, branch SHAs vs origin, and MR
target branches are checked live at write time. A summary that says "green"
when CI is red is worse than no summary.

## 2. Sections (the contract)

**TL;DR** — 3–4 sentences: what the feature does, how it's built, its quality
state (tests/verification/review), and the one thing the reader must do next.

**MRs & PRs + merge order** — one table: number/link, one-line what, where,
target branch. Then a NUMBERED merge order that is *safe*: stacked MRs
top-down with "retarget child to <default> as each parent merges"; cross-repo
ordering (e.g. infra before the service that needs its secrets; producer
before consumer); "anytime" items last. Note anything that must NOT be merged
(superseded prototypes, local-only integration branches).

**Manual steps for you** — the human-only work, as runnable commands where
possible: secrets to mint (`aws ssm put-parameter ...` with shared-value
snippets), env vars to set (name, value, which service, where it's read),
credential edits, feature-flag flips, retarget-after-merge chores, one-off
jobs to kick (backfills/reconciles). If none: say so.

**Database changes** — per migration: table/index/constraint added or changed,
which app owns it, production-safety notes (strong_migrations pattern used,
concurrent indexes, shared-DB visibility grants or their deliberate absence).
Call out anything irreversible.

**Risks & accepted trade-offs** — only decisions the reader might regret not
knowing: known races and their backstops, security posture calls (who accepted
them), flaky-area proximity, deploy-order hazards. Pull from adversarial-review
survivors and decision logs; 3–7 bullets max.

**Test / seed / reset scripts** — exact paths + exact invocations for anything
that flips local state (e.g. `yc ssh internal development -c 'bin/rails runner
/mnt/data/workspace/code/tmp/<seed>.rb'`), what each does, and the reset
script. Include any minted dev sessions/cookies (value + expiry + how to
revoke). If none: one line.

**Rollback plan** — per shipping unit, in reverse merge order: how to turn it
off WITHOUT a revert when possible (env off-switch, feature gate, secret
removal = fail-closed), then the revert-MR path, then migration caveats
(new empty tables are safe to leave; dropping columns/data is the dangerous
direction — say explicitly what must NOT be rolled back once data exists).

**Screenshots & bug bash** (only when UI/UX changed) — embed existing
verification screenshots (relative paths so the report is portable) in a grid
with one-line captions; state the bug-bash/browser-verification outcome
(states exercised, live-transition timings, console findings). If UI shipped
with NO browser evidence, say so loudly and offer to run a verification pass
(claude-ui-test agent / the factory verification phase) before finishing the
report — don't silently ship an unverified-UI summary.

**Test it manually** — clickable local URLs built from `yc stacks url` (never
hardcoded hosts) with REAL record ids/logins (per the user's global rules),
plus the state-flip commands inline; prod URLs where the change is already
live. One box, copy-paste ready.

## 3. Write + deliver

1. Copy `TEMPLATE.html` (same dir as this skill; expand `~` to `$HOME`) and
   fill it — keep its CSS/structure; delete unused sections entirely rather
   than leaving stubs.
2. Save to `docs/specs/<slug>-work-summary.html` and `open` it.
3. Chat message: 5-line TLDR + the report path + the single most important
   manual step. Do NOT paste the whole report into chat.
4. If a factory scoreboard (`.context/factory-status.md`) exists, update it to
   point at the report.

## Notes

- `/factory` runs produce this as their final phase — invoke `/work-summary`
  there instead of hand-writing a report.
- Re-runs are cheap and expected: re-invoking /work-summary after fixes should
  regenerate the report in place (same filename) with fresh pipeline states.
- Multi-repo work: one report covering all repos beats one per repo.
