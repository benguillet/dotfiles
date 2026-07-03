---
name: factory
description: Ship an approved spec as a fleet of small stacked MRs/PRs across repos — decompose, build each unit with a scoped subagent, verify in the browser with seeded data, adversarially review with a find→refute agent fleet, fix on the owning branches, and deliver an HTML launch report. Crash-resilient (survey → TaskStop zombies → relaunch) with always-visible progress (task list + status scoreboard + heartbeats). TRIGGER when the user types /factory <spec/plan path, gdoc link, or description>, or asks to "implement the spec as stacked MRs", "run the factory", or to turn an approved plan into shippable MRs end to end.
---

# /factory — spec in, reviewed MR fleet out

Turn an approved implementation plan into merged-ready work: small stacked
MRs/PRs, each built + tested by a scoped subagent, then browser-verified,
adversarially reviewed, fixed, and summarized in an HTML report. Born from the
Paxel account-state build (10 shipping units, 3 repos, 88 review agents); the
recovery and visibility rules below are the lessons of that run — follow them
even when they feel like ceremony.

Companion files (same dir; expand `~` to the real `$HOME` before use):
- `RECOVERY.md` — crash recovery + environment quirks. Read it at kickoff.
- `adversarial-review.workflow.js` — parameterized review fleet for phase 6.

## Two iron rules (the user's actual requirements)

1. **Never lose the run.** Every unit of work is committed and pushed the
   moment it passes checks. Any agent can die at any time (laptop close kills
   local agents); recovery must always be "survey git, relaunch the one lost
   step", never "start over".
2. **The user can always see what's happening.** Task list + scoreboard file +
   milestone messages are not optional. If the user asks "status?" the answer
   must already exist on disk.

## 0. Kickoff

1. Resolve the plan from `$ARGUMENTS` (file path, gdoc link, or description).
   **/factory requires an APPROVED plan.** If there is only a spec or an idea:
   produce the plan first (draft, optionally cross-critique with `/codex`
   consult, reconcile), present it with open questions, and STOP for approval.
2. Ask ONE question (AskUserQuestion): **Autonomous** (default — run everything,
   notify at milestones) or **Checkpointed** (pause for approval after
   decomposition and before applying review fixes).
3. Read `RECOVERY.md`. Resolve repo-specifics from the project's CLAUDE.md
   (test/lint commands, MR conventions, migration rules) — never assume.
4. **Decompose** into shipping units: prefer many small stacked MRs over few
   big ones (stacked = branch chain `<prefix>-NN-<slug>`, each MR targets its
   parent's branch; first targets the default branch; GitHub repos get one PR —
   no stacking). Identify the lanes: units in DIFFERENT repos/checkouts can run
   in parallel; units sharing a checkout are strictly sequential (rule: **one
   git writer per working tree, ever**).
5. **Set up visibility** before any building:
   - `TaskCreate` one task per shipping unit + one per phase (verify, review,
     report). `TaskUpdate` status/owner at EVERY transition.
   - Write the scoreboard: `.context/factory-status.md` — phase, per-unit
     table (unit, branch, MR link, state, owner agent), what's in flight,
     what's next, last-updated timestamp. Rewrite it at every milestone;
     it is the crash-surviving source of truth.
   - Arm a `ScheduleWakeup` heartbeat (1200–1800s) whose prompt says: check
     agents, recover per RECOVERY.md, continue the factory pipeline per the
     task list and `.context/factory-status.md`. Re-arm it each phase; do NOT
     use wakeups for streaming (use Monitor when there's a pollable signal).

## 1–3. Build the lanes

For each lane, dispatch ONE scoped subagent per shipping unit, sequentially
within the lane, parallel across lanes. Every build-agent prompt must include:

- Exact branch to create and its parent; "stage only your files; NEVER
  `git add -A`; never `--amend`; never commit scratch dirs (docs/specs,
  .context, tmp)".
- The full contract it implements (inline — agents don't share your context)
  plus pointers to the spec/plan files on disk.
- The check gate: repo test + lint commands from CLAUDE.md; iterate until
  green; report results HONESTLY (a known-broken harness step gets a validated
  substitute, documented — see RECOVERY.md quirks — never a skipped check).
- Ship steps: commit (co-author trailer per repo rules) → push → create the
  MR/PR (target = parent branch; no reviewers, no auto-merge; description
  names its place in the stack) → leave the tree on the new branch.
- "Report back: MR URL, files, honest check results, and what the NEXT unit
  must know" — feed each report's contract notes into the next prompt.
- Anti-watchdog rule: no single silent >10min command — redirect long commands
  to a log file and poll it.

Cross-repo contract notes (e.g. "the client keys acks on exact uuid echo")
must be relayed to the agent building the other side — you are the bus.

After each unit lands: TaskUpdate, refresh the scoreboard, one-line milestone
message to the user with the MR link.

## 4. Local integration + browser verification

1. Build a LOCAL-ONLY integration branch (`local/<feature>-integration`)
   merging every lane's tip; never push it. Run migrations; smoke-test the key
   endpoint(s) with curl before spending a browser agent.
2. Dispatch a browser agent (claude-ui-test type) with: exact URLs, login
   recipe (see RECOVERY.md for the dev-SSO-session mint if the login app isn't
   running), seed scripts it runs between screenshots (write them to tmp/,
   never committed), the per-state assertions, and a hard timebox + "stop and
   report, don't loop" rule for anything environmental.
3. Deliverables: screenshots into `docs/specs/images/verification/`, a PASS/
   FAIL table, and a live end-to-end transition test where the feature has one
   (poll flip, webhook, etc.). Console errors triaged: new-feature errors are
   failures; pre-existing noise is noted.

## 5. (While verification runs) nothing blocks — prep the report skeleton or
idle; review can also start now since it's read-only on pushed refs.

## 6. Adversarial review — the whole point of the factory

Run `Workflow({ scriptPath: '<skill-dir>/adversarial-review.workflow.js',
args: { diffs, crosschecks, settled, context_files } })` — see the script
header for the args contract. Principles:
- Finders are READ-ONLY over pushed refs (`git diff origin/base...origin/head`)
  so they can run concurrently with anything.
- Every diff gets ≥3 lenses (correctness+concurrency, security, house-rules+
  test-honesty) plus domain lenses; multi-repo contracts get a dedicated
  cross-check finder that reads BOTH sides.
- Findings must state a concrete failure scenario; each is attacked by 2
  independent refuters (kill on unanimous refute; note PLAUSIBLE on split).
- Feed `settled` (decisions already made) so the fleet doesn't relitigate.
- The Workflow journal is your crash insurance: on any interruption, resume
  with `resumeFromRunId` — completed agents replay from cache.

Consolidate survivors into unique defects (the same bug arrives through
several lenses). If Checkpointed mode: present them and wait.

## 7. Fixes

Dispatch one fix agent per repo/lane (parallel across repos, one per tree):
each fix lands ON THE BRANCH THAT OWNS THE FILE, children rebase on top,
`--force-with-lease` push, and a "review fixes" note is posted on each touched
MR/PR. Fix agents may overrule a finding while implementing — require them to
say so with reasoning (verified example: a reviewer's suggested fix that would
have regressed data-model behavior). Re-run the unit's check gate after fixes.
Rebuild the integration branch from the fixed tips so local testing reflects
final code.

## 8. HTML launch report

Write `docs/specs/<feature>-launch-report.html` and `open` it. Required, keep
it SHORT: 3–4 sentence summary · table of every MR/PR with links and targets ·
numbered merge order (including manual infra steps and retarget-on-merge
notes) · screenshot grid (relative paths) · "test it locally" box with real
URLs, real record ids, the seeded session/login, and the state-flip commands ·
quality-gates list (test counts, verification result, review stats: agents,
raw→verified→unique-fixed, severity highlights) · outstanding manual steps.
Then post the final chat summary: TLDR, links, merge order, what's left for
the human.

## Recovery contract (applies to every phase)

On ANY agent/workflow death, stall notice, or session restart — follow
`RECOVERY.md`. The short version: **survey first** (git status + local-vs-
origin SHAs in every lane; scoreboard file), **TaskStop the presumed-dead
agent before relaunching** (suspended agents can resurrect and race their
replacement), relaunch only the lost step with a "verify inherited state,
then continue" prompt, and update the scoreboard. Never rebuild what origin
already has.
