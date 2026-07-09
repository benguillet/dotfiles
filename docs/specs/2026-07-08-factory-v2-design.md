# Factory v2 — workflow-native pipeline with a session state store

**Status:** approved design, pre-implementation
**Date:** 2026-07-08
**Owner:** Ben Guillet

## Problem

The current `/factory` skill orchestrates almost everything in the main agent
loop: prose instructions, hand-managed task lists, and a scoreboard file. Only
phase 6 (adversarial review) is a real Workflow script. Consequences:

1. **No live visibility.** `/workflows` shows only the review phase. For the
   rest, "what is it doing right now / where is the time going" has no answer
   short of reading the scoreboard file.
2. **No reusable pieces.** The review fleet, research fan-out, and planning
   logic can't be invoked outside the factory.
3. **The pipeline shape is dated.** It starts from an approved plan; there is
   no triage, no intent sharpening, no research dossier, no dual-model
   planning, no risk pass — all of which `feature-pipeline` proved out at
   single-task scale.

## Goals

- Every long-running phase is a Workflow script, watchable live in
  `/workflows` with meaningful phase groups, agent labels, and `log()` lines.
- The pipeline follows the proven shape: triage → sharpen⇄research →
  dual-model plan → human checkpoint → finalize/select → plan review + risk →
  parallel build with per-unit adversarial codex review → code review panel +
  browser verify → fix → report.
- A per-run **session state store** on disk (`~/.factory/runs/<run-id>/`)
  records status, events, and every phase artifact — machine-readable, ready
  to back a future control plane (web app listing all sessions live), and
  migratable to SQLite later.
- Crash recovery keeps the iron rule: **never lose the run**. Laptop-close
  (new session) recovery works via git survey + artifact-idempotent workflow
  re-entry, not via same-session `resumeFromRunId` alone.
- Reusable extraction: the review panel becomes its own skill
  (`/review-panel`), usable by factory (twice), directly, or by other skills.
- Keep it as simple as the problem allows. No over-engineering; complexity
  must earn its place.

## Non-goals

- **`feature-pipeline` is not touched.** It stays as-is (queue/backoff front
  door for small autonomous tasks); Ben will likely retire it later, as a
  separate decision.
- No SQLite yet; plain files.
- No control-plane UI in this project — only the on-disk contract it will read.

## Architecture overview

Two layers:

1. **Conductor** — the main agent loop following `SKILL.md`. Thin by contract:
   resolve the prompt, run interactive checkpoints (only the conductor can
   `AskUserQuestion`), chain workflows, persist workflow results into the
   session store, stamp timings, recover from crashes. It never builds,
   reviews, or fixes anything itself.
2. **Workflows** — one script per phase, launched via
   `Workflow({scriptPath, args})`. All heavy lifting happens here, visible in
   `/workflows`.

```
prompt in
  → TRIAGE            conductor-inline cheap agent: trivial? user-facing?
  trivial ──────────→ BUILD (single unit) → panel(code, slim) → report
  → SHARPEN ⇄ RESEARCH  conductor asks the human ⇄ research.workflow (≤ ~3 loops) → intent.md
  → PLAN-DRAFT        workflow: fable(xhigh) ∥ codex(gpt-5.6-sol) draft → cross-critique → open questions
  → CHECKPOINT        conductor surfaces open questions to the human
  → PLAN-FINALIZE     workflow: both revise (critique + answers) → codex selects → plan.md + dag.json
  → PLAN PANEL ∥ RISK  review-panel(mode=plan) ∥ risk.workflow — both read-only, run concurrently
  → PLAN AMEND        one agent applies confirmed findings + risk mitigations to plan.md/dag.json
  → BUILD             workflow: DAG executor, worktree-parallel; per unit:
                      implement → codex adversarial review → address/overrule → gates → push → MR/PR
  → CODE PANEL ∥ VERIFY  review-panel(mode=code) ∥ verify.workflow — panel reads pushed refs, verify uses local integration
  → FIX               workflow: confirmed findings fixed on owning branches → rebase children → rebuild integration → re-seed state 1
  → REPORT            /work-summary skill (extended template)
```

In **Checkpointed** mode the conductor also pauses after plan amend (final
plan approval) and before fix (findings approval). In **Autonomous** mode
(default) it only stops at the plan-draft open-questions checkpoint (and only
if there are questions).

## Session state store

One directory per run: `~/.factory/runs/<run-id>/` where
`run-id = YYYY-MM-DD-<feature-slug>`. Global (outside any repo) because runs
span repos/worktrees and a control plane wants one directory to scan.

```
~/.factory/runs/2026-07-08-example-feature/
├── state.json          # single source of truth — conductor-owned, atomic rewrite (tmp+rename)
├── events.jsonl        # append-only event log — conductor AND agents append
├── STATUS.md           # human-readable render of state.json, regenerated at milestones
└── artifacts/
    ├── intent/intent.md
    ├── research/research.md
    ├── plans/plan.claude.md, plan.codex.md, critique-*.md, plan.claude.v2.md, plan.codex.v2.md
    ├── plan/plan.md + dag.json
    ├── risk/risk.md
    ├── review-plan/findings.json
    ├── build/unit-<id>.json          # MR URL, checks, codex-review outcome, overrules
    ├── review-code/findings.json
    ├── verify/verification.md + screenshots/*.png
    ├── fix/fixes.json
    └── report/launch-report.html
```

- **`state.json`** — run metadata (`run_id`, `feature`, `mode`,
  `created_at`/`updated_at`), current phase, per-phase
  `{status, started_at, ended_at, workflow_run_id, artifacts[]}`, per-unit
  `{id, repo, dir, branch, base, deps, status, mr_url, timings}`, and artifact
  paths. Everything a control-plane session card needs; MR pipeline/comment
  state is *not* stored (the control plane or report step polls `glab`/`gh`
  live using the stored URLs).
- **`events.jsonl`** — one JSON object per line:
  `{ts, type, unit?, by, detail?}` (`phase_started`, `unit_started`,
  `unit_pushed`, `mr_created`, `finding_confirmed`, …). `by` is
  `conductor` or `agent:<label>`. This is the future SQLite table.
- **Writers.** Workflow *scripts* have no filesystem access, so: the
  **conductor** persists each workflow's return value into `artifacts/` and
  rewrites `state.json` at every milestone; the **agents inside** workflows
  (which do have tools) receive the session dir in their prompts, append
  their own events, and drop their own artifacts. This keeps the store live
  mid-phase, not just at boundaries.
- Timestamps come from real `date -u +%Y-%m-%dT%H:%M:%SZ` (never invented —
  `Date.now()` doesn't exist inside workflow scripts).
- Full field-level schemas live in
  `skills/factory/references/state-format.md` — that file is the
  control-plane API contract.

## Recovery contract

Iron rule unchanged: never lose the run; the user can always see what's
happening.

- Every unit is committed and pushed the moment it passes its gates.
- **Artifact-idempotent workflows** (pattern proven in feature-pipeline):
  every workflow starts with a cheap probe agent that lists the session dir;
  each stage is guarded by "does my artifact already exist?". Re-running a
  workflow after any interruption skips completed stages in seconds — in any
  session, no journal needed.
- Same-session interruptions can additionally use `resumeFromRunId` (journal
  cache), but correctness never depends on it.
- Build/fix recovery adds **git survey**: per unit, compare local vs origin
  SHAs; classify pushed / committed-not-pushed / uncommitted / absent; the
  conductor passes only unfinished units back into the workflow, and each
  build agent's prompt starts with "survey first — if `origin/<branch>`
  exists with an open MR, verify and report DONE".
- `TaskStop` presumed-dead agents before relaunching (zombie resurrection).
- Heartbeat `ScheduleWakeup` (1200–1800s) re-armed each phase: check agents,
  recover per RECOVERY.md, continue per `state.json`.
- `RECOVERY.md`'s environment quirks (watchdog, migration locks, worktree
  hooks, shell traps) carry over unchanged.

## The review panel — standalone skill `skills/review-panel/`

Front door `/review-panel` + `panel.workflow.js`. Evolves the existing
`adversarial-review.workflow.js` machinery (find → dedup → N independent
refuters per finding → CONFIRMED / PLAUSIBLE / REFUTED), fixing three known
bugs (below), and adding **mode-specific lens sets**.

### args contract

```
{
  mode: 'plan' | 'code',
  targets: [...],           // code mode: diffs [{key, dir, base, head, context}]
                            // plan mode: files [{key, path, context}]
  focus: ['path or area'],  // each gets ONE extra full red-team reviewer scoped to it
  lenses: ['correctness'],  // optional override: run ONLY the named axes
  settled: ['decision …'],  // do-not-relitigate list
  context_files: [...],     // intent.md, research.md, plan.md as applicable
  refuters: 2,
  session_dir: '...'        // events + findings.json land here (agents write)
}
```

### Code mode — 10 axes (verbatim, the default lens set)

1. **correctness** — logic/edge/nil/off-by-one, bad state transitions, logic vs intent
2. **security** — injection/XSS/IDOR/authz, secrets, SSRF, validation, PII exposure
3. **concurrency** — races, TOCTOU, check-then-act, idempotency (favors DB primitives over app guards)
4. **edge-errors** — unhandled/partial failure, boundary guards, swallowed exceptions (rescue StandardError)
5. **perf-scale** — N+1s, unbounded loads, missing indexes, hot paths; /evaluate-scale + shared-pool impact on scaling-sensitive areas
6. **contract** — changed signatures/return shapes/scopes/migrations, shared concerns, cross-app (bookface↔ycinternal) call-site ripple, back-compat
7. **tests** — do tests actually pin behavior? vacuous/tautological, flaky, real coverage of the change
8. **cruft** — over-engineering, premature abstraction, dead code, unearned indirection, deletable code (primary target)
9. **maintainability** — misleading names, hard-to-follow intent, structure that trips the next dev
10. **intent-fit** — does it do what intent requires? gaps and over-build

### Plan mode — 9 axes (verbatim)

1. **scope-creep** — YAGNI, gold-plating, speculative generality; what can be cut
2. **complexity** — hidden complexity, unneeded abstraction, is there a simpler design (primary target)
3. **edge-failure** — missing edge cases, failure/error paths, races, rollout/migration conditions
4. **boundaries** — wrong layer (controller/model/concern), leaky boundaries, integrity in app vs DB
5. **testability** — is "done" verifiable? what's the oracle/acceptance criteria
6. **risk** — blast radius, rollout/rollback safety, irreversibility, dependency-ordered decomposition
7. **assumptions** — unstated assumptions + WHAT questions that must be answered first (→ escalations)
8. **approach** — is the core approach right / is there a better one / does it solve the stated problem
9. **plan-correctness** — internal gaps, contradictions, wrong ordering, self-inconsistency

Notes that shape the implementation:

- Axis definitions reference YC-monorepo specifics (bookface↔ycinternal,
  `/evaluate-scale`, `rescue StandardError`); finders are additionally told to
  read the target repo's CLAUDE.md/AGENTS.md, so the axes degrade gracefully
  on non-YC repos.
- Cruft (code) / complexity (plan) are first-class primary targets, not
  afterthoughts.
- Every finding from every axis goes through the independent refute step
  before it can drive a change. Survivors whose fix is *deletion* get tagged
  `overbuild: true` — a data source for the report's "possibly-unneeded work"
  section.
- Findings state a concrete failure scenario (state + trigger → observable
  wrong behavior); no linter-enforceable style nits; severity
  critical/major/minor as today.

### Bug fixes carried into `panel.workflow.js`

1. **Finder attribution misalignment** — `results.filter(Boolean).flatMap((r, i) => …finders[i]…)`
   reindexes after a dead finder, mis-tagging every later finding's lens. Fix:
   tag before filtering (`results.flatMap((r, i) => r ? … : [])`).
2. **Dead refuters auto-CONFIRM** — zero surviving refuter votes currently
   yields `refutes === 0` → CONFIRMED. Fix: `votes.length === 0` →
   PLAUSIBLE (never CONFIRMED without a live verifier).
3. **Dedup key drops distinct findings** — key is `file|title.slice(0,40)`
   ignoring `line`; two different bugs in one file with similar titles
   collide. Fix: include `line ?? ''` in the key.

## The codex wrapper

Canonical template documented in `skills/factory/references/codex-job.md`;
each workflow that calls codex embeds it by convention (workflow scripts
cannot import local modules — acceptable, documented duplication).

- Verified model ID: **`gpt-5.6-sol`** (GPT-5.6 family, Sol = flagship tier;
  announced 2026-06-26; configured as `-c model="gpt-5.6-sol"`). In limited
  preview at design time, GA expected within weeks.
- Reasoning effort: `model_reasoning_effort="xhigh"`. GPT-5.6 adds
  `max`/`ultra`, but `ultra` spawns codex-internal sub-agents — redundant and
  token-explosive inside a pipeline that already fans out. Not used.
- The model is a single constant per script, overridable via workflow `args`
  (`codex_model`).
- **No fallback authoring** (feature-pipeline policy, kept): if codex is
  missing, unauthenticated, or the model is unavailable to the account, the
  stage returns `ok=false` with ONE actionable line (e.g. "gpt-5.6-sol not
  available on this account yet — set codex_model=gpt-5.5 or wait for GA");
  the conductor surfaces it and pauses the phase. Claude never ghost-writes
  codex's deliverables — an independent second model is the point.
- Invocation shape (proven in feature-pipeline): prompt written to a temp
  file, `timeout 660 codex exec -s read-only "$(cat <tmpfile>)" -c
  model="gpt-5.6-sol" -c 'model_reasoning_effort="xhigh"'
  --output-last-message <tmp-out> < /dev/null`, one retry on transient
  failure, output landed verbatim with an `<!-- author: codex -->` first line.
  Every codex prompt is prefixed with the boundary line telling it not to
  read `~/.claude`/agent definitions.

## Phase details

### Triage (conductor-inline)

One cheap agent (haiku, low effort): `trivial` + `userFacing`, criteria as in
feature-pipeline (≤~50 lines, no design fork, no schema/API changes; unsure →
NOT trivial). Trivial path: single-unit build workflow (same per-unit codex
review gate) → slim code panel (`lenses: [correctness, tests, cruft]`) →
report; user-facing trivial changes additionally get one browser-verify agent
(screenshot + smoke) so the report's screenshot/test-locally sections still
hold. No plan, no risk workflow. Triage is not a workflow itself — one agent
call, logged to `state.json`.

### Sharpen ⇄ Research

- **Sharpen is conductor-owned** (workflow agents can't ask the user):
  rounds of `AskUserQuestion` — each question with why-it-matters and a
  suggested default. The conductor writes `intent.md` (Goal / Success
  criteria / In scope / Out of scope / Assumptions).
- **`research.workflow.js`**: routes 2–5 read-only scouts — code, tests,
  history, runtime, external (web), ui-vocab (user-facing only) — reusing
  feature-pipeline's scout charters, then one synthesizer writes
  `research.md` (TL;DR, key-files map, conventions, risks & gotchas, open
  unknowns, how to test, UI vocabulary). Scout fan-out uses the Explore agent
  type where applicable.
- Loop: research may run before questions (ground them) and re-run with a
  refined focus if answers change what to look for. Soft cap ~3 loops, then
  proceed with documented assumptions.

### Plan-draft workflow

- Two planners in parallel: `plan:claude` with `{model: 'fable', effort:
  'xhigh'}`, `plan:codex` via the codex wrapper. Both read `intent.md`,
  `research.md`, and write standalone-executable plans (Approach + rejected
  alternative / ordered steps with file paths / data & schema changes /
  testing strategy / rollout & flags / risks / out of scope) **plus a
  "Shipping units & dependency order" section** — per unit: repo, dir,
  branch, base, deps, contract, notes-for-dependents.
- Cross-critique: each critiques the other's plan (claude critiques codex's,
  codex critiques claude's) against intent + research; user-facing work adds
  a UX/IA critique of both. Every critique ends with
  `## Open questions for the human` (only requester-owned forks, each with a
  suggested default).
- Returns: plan/critique summaries + consolidated open questions.

### Human checkpoint

Conductor presents the open questions (AskUserQuestion, batched, with the
suggested defaults). Answers are appended to the session store and fed into
plan-finalize. No questions → skip.

### Plan-finalize workflow

- Each author revises its own plan using the critiques it received + the
  human's answers (accept valid criticism, push back explicitly where the
  critic is wrong).
- **Codex selects** the stronger plan (or merges) → `plan.md` (first line
  records `Chosen: claude|codex|merged — rationale`).
- A final extraction step emits the machine-readable `dag.json` from the
  chosen plan's shipping-units section:

```json
{ "units": [ { "id": "u3", "repo": "paxel", "dir": "/Users/ben/Work/yc/paxel",
    "branch": "ben/feat-03-slug", "base": "master", "deps": ["u1"],
    "contract": "…full inline contract…", "notes_for_dependents": "…" } ],
  "crosschecks": [ … ], "settled": [ … ] }
```

### Plan panel ∥ Risk (concurrent — both read-only over plan.md)

- `review-panel` in plan mode (9 axes; `focus` = plan sections touching
  migrations/auth/money/etc. as the conductor judges; `settled` = human
  answers + resolutions).
- **`risk.workflow.js`**: deployment risk, rollback recipe per unit and for
  the whole fleet, deploy/merge order (including manual infra steps),
  blast radius, irreversibility (migrations, data backfills), monitoring
  hooks. Output `risk.md` + per-unit risk annotations merged into `dag.json`.
- **Plan amend**: one conductor-dispatched agent applies CONFIRMED panel
  findings + risk mitigations to `plan.md`/`dag.json`, recording each change.
  Checkpointed mode pauses here for approval of the final plan.

### Build workflow

- **DAG executor**: launch every unit whose deps are all done; as units
  finish, launch newly unblocked ones (no global barrier). Independent units
  run concurrently even within one repo — each build agent in its own git
  worktree; dependent units run sequentially and receive their parents'
  `notes_for_dependents` (the script is the bus for cross-repo contract
  notes). One git writer per working tree, always.
- Per-unit gate sequence: implement → **codex adversarial review** of
  `git diff` (read-only, contract-aware, explicit simplicity mandate: "flag
  over-engineering and unneeded guards as findings") → build agent addresses
  each finding or **overrules with stated reasoning** (recorded in
  `unit-<id>.json`; feeds the report) → repo gates (test + lint commands from
  the repo's CLAUDE.md; honest reporting; validated substitutes documented,
  never skipped checks) → commit (co-author trailer; never `--amend`; stage
  only own files) → push → MR/PR (target = parent branch or default; no
  reviewers; no auto-merge; description names its place in the stack) →
  events + artifact to the session dir.
- Anti-watchdog: no silent >10 min command — redirect to a log file and poll.
- Simplicity mandate in every build prompt: as simple as the contract allows;
  no speculative generality.

### Code panel ∥ Verify (concurrent)

- `review-panel` in code mode over the fleet's pushed diffs
  (`git diff origin/base...origin/head` per unit repo), `crosschecks` from
  `dag.json` for multi-repo contracts, `focus` from `risk.md` watch areas.
- **`verify.workflow.js`**: build a LOCAL-ONLY integration branch
  (`local/<feature>-integration`) merging every lane tip (never pushed);
  run migrations; curl smoke-test key endpoints; then browser agents
  (claude-ui-test type) with exact URLs, login recipe, seed scripts (written
  to tmp/, never committed), per-state assertions, hard timebox +
  "stop and report, don't loop" for environment issues. Deliverables:
  screenshots into the session store, PASS/FAIL table, live end-to-end
  transition test where the feature has one; console errors triaged
  (new-feature errors are failures).

### Fix workflow

- One fix agent per affected repo (worktree-isolated, parallel across repos):
  each confirmed finding fixed **on the branch that owns the file**, children
  rebased, `--force-with-lease` push, "review fixes" note on each touched
  MR/PR. Fix agents may overrule a finding while implementing — required to
  say so with reasoning.
- Re-run the unit's gates after fixes; rebuild the integration branch from
  fixed tips; **re-run the seed for manual-test state 1** so the local env is
  ready when the report lands.
- Checkpointed mode: conductor presents consolidated findings before this
  phase runs.

### Report

Invoke `/work-summary`; its template (in `skills/work-summary/`) is extended
to this contract. Required sections, in order:

1. **ELI5 summary** — max 5 sentences, plain language, no jargon.
2. **How it works** — 1–3 Mermaid flow charts/schemas rendered in the HTML:
   who calls what in what order, data flow, state machine if any.
3. **Database changes** — each migration with its schema delta, or "None".
4. **Risk** — distilled from `risk.md`: blast radius, rollback recipe,
   deploy order.
5. **Possibly-unneeded work** — honest list of guards/complexity built for
   very edge-casey scenarios; sources: overruled codex findings,
   `overbuild`-tagged panel survivors, risk notes. Each entry: what it
   guards, "keep because / could delete if".
6. **MRs/PRs** — table: link, target branch, merge order (including manual
   infra steps and retarget-on-merge notes), **live pipeline status and
   unresolved-comment count** fetched via `glab`/`gh` at report time.
7. **Screenshots** — grid (relative paths), only if UI/UX changed.
8. **Test it locally** — clickable local URLs (base from `yc stacks url`,
   real record IDs, never placeholders), the seeded login/session, seed
   scripts for each further state, with **state 1 already seeded**.

Report file: `artifacts/report/launch-report.html` in the session store
(plus `open` it). Final chat message: TLDR, links, merge order, what's left
for the human.

## Observability & timing

- **Live**: `/workflows` per phase — agents labeled
  (`build:u3:paxel`, `find:code:security`, `refute2:<title>`), grouped under
  phase titles, native per-agent elapsed time; `log()` narration at every
  milestone; mid-phase `events.jsonl` + `STATUS.md` updates.
- **Post-hoc**: conductor stamps phase start/end (shell `date`); per-unit
  timings from agent-appended events; the report gains a "where the time
  went" table (per phase + slowest units/agents).
- Heartbeat wakeup doubles as a stall detector.

## File layout (ai-setup repo)

```
skills/review-panel/            # NEW standalone skill
├── SKILL.md                    #   /review-panel front door (mode, targets, focus, lenses)
└── panel.workflow.js           #   9+10 axes, focus red-teams, refute verify (bugs fixed)

skills/factory/
├── SKILL.md                    # rewritten: thin conductor (spine, checkpoints, state store, recovery)
├── RECOVERY.md                 # updated: state.json-first survey, artifact re-entry, git survey
├── references/
│   ├── state-format.md         # state.json / events.jsonl / artifacts contract (control-plane API)
│   └── codex-job.md            # canonical codexJob template + model pin (gpt-5.6-sol)
└── workflows/
    ├── research.workflow.js
    ├── plan-draft.workflow.js
    ├── plan-finalize.workflow.js
    ├── risk.workflow.js
    ├── build.workflow.js
    ├── verify.workflow.js
    └── fix.workflow.js

skills/work-summary/            # template extended with the 8-section report contract
skills/factory/adversarial-review.workflow.js   # DELETED (superseded by review-panel)
```

`~/.claude/skills/` symlinks: `factory` already points into the repo;
add `review-panel → /Users/ben/Work/ai-setup/skills/review-panel`.

## Implementation notes & shared conventions

- All workflow scripts adopt feature-pipeline's hardening: `retryAgent`
  (retry throws + one null, then degrade), transient-failure returns instead
  of run-killing throws, prompt fencing for untrusted text, absolute-path
  validation on any path interpolated into shell commands, `READ_ONLY`
  preamble for read-only agents.
- Probe-then-skip (artifact idempotence) at the top of every workflow.
- `meta.phases` titles must exactly match `phase()` calls; every `agent()`
  sets `label` and `phase`.
- Effort routing: mechanical stages `low`; finders/refuters/judges `high`;
  claude planner `{model: 'fable', effort: 'xhigh'}`.
- Verify `gpt-5.6-sol` availability on Ben's account during implementation
  (limited preview at design time); the `codex_model` arg is the escape hatch.
- The conductor keeps using TaskCreate/TaskUpdate for phase/unit tracking in
  the harness UI, in addition to the session store.

## Open questions (deliberately deferred)

- Retiring `feature-pipeline` (likely, later; out of scope here).
- SQLite migration for the state store (the `events.jsonl` schema is designed
  to import cleanly when that day comes).
- Control-plane app itself (separate project; consumes
  `references/state-format.md`).
