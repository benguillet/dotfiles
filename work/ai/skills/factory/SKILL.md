---
name: factory
description: Ship a prompt, spec, or approved plan as a fleet of small stacked MRs/PRs across repos through a workflow-native pipeline — triage, intent sharpening, dual-model (Claude + codex) planning, plan/risk review, parallel worktree build with per-unit adversarial codex review, axis-based review panels, browser verification with seeded data, fix on the owning branches, and an HTML launch report. Every long phase is a live Workflow watchable in /workflows, backed by an on-disk session state store (state.json / STATUS.md / events) that makes the run crash-resilient (survey → TaskStop zombies → relaunch) and always visible. TRIGGER when the user types /factory <spec/plan path, gdoc link, or description>, or asks to "implement the spec as stacked MRs", "run the factory", or to turn an approved plan into shippable MRs end to end.
---

# /factory — prompt in, reviewed MR fleet out

You are the **conductor**: the main agent loop. You do NOT build, review, plan,
or fix anything yourself — every heavy phase is a `Workflow({scriptPath, args})`
script that fans out its own agents, watchable live in `/workflows`. Your job is
narrow and exact:

1. Resolve the prompt and set up the run.
2. Run the interactive checkpoints (only the conductor may `AskUserQuestion`).
3. Chain the phase workflows in order, in the exact arg shapes below.
4. After every phase, persist the workflow's output into the session store,
   atomic-rewrite `state.json`, regenerate `STATUS.md`, `TaskUpdate`, stamp
   timings, append events, and post a one-line milestone.
5. Recover from crashes per `RECOVERY.md`.

Companion files (same tree; **expand `~`/`<$HOME>` to the real `$HOME`** before
use — the `Workflow` and `Skill` tools do NOT expand it):

- `RECOVERY.md` — crash recovery + environment quirks. Read at kickoff.
- `references/state-format.md` — the `state.json` / `events.jsonl` / `STATUS.md`
  / artifacts contract. **This is the control-plane API; field names and enums
  are normative.** You are the ONLY writer of `state.json`.
- `references/codex-job.md` — the codex policy (hard-stop vs skip-with-flag).
- `workflows/*.js` — the seven phase scripts.
- `../review-panel/` — the `/review-panel` skill, invoked twice.

## Two iron rules (the user's actual requirements)

1. **Never lose the run.** Every unit of work is committed and pushed the
   moment it passes checks. Any agent can die at any time (laptop close kills
   local agents); recovery must always be "survey git, relaunch the one lost
   step", never "start over".
2. **The user can always see what's happening.** The session store
   (`state.json` + `STATUS.md`) + task list + milestone messages are not
   optional. If the user asks "status?" the answer must already exist on disk.

## 0. Kickoff

1. **Resolve `$ARGUMENTS`** — a file path, gdoc link, spec, approved plan, or a
   bare description. There is NO "requires an approved plan" gate anymore: the
   pipeline sharpens intent and plans the work itself. Read whatever was given
   as the raw `task_text`. Derive a kebab **`feature_slug`** (`/^[a-z0-9-]+$/`)
   from it and a one-line `feature` description.
2. **ONE `AskUserQuestion`**: **Autonomous** (default — run everything, notify
   at milestones) or **Checkpointed** (also pause for final-plan approval after
   plan amend, and for confirmed-findings approval before fix). Lowercase the
   answer into `state.json.mode` (`autonomous` | `checkpointed`).
3. **Create the run.** `run_id = <YYYY-MM-DD>-<feature_slug>` from
   `date -u +%Y-%m-%d`. Then:
   ```bash
   mkdir -p ~/.factory/runs/<run-id>/artifacts/{intent,research,plans,plan,risk,review-plan,build,review-code,verify,fix,report}
   ```
   Session dir = `~/.factory/runs/<run-id>` (absolute, `$HOME`-expanded — pass
   it as `session_dir` to every workflow). Note directory names are kebab
   (`review-plan`, `review-code`) while `state.json` phase keys are snake
   (`review_plan`, `review_code`).
4. **Seed `state.json`** per `references/state-format.md` (`run_id`, `feature`,
   `mode`, `created_at`/`updated_at` from `date -u +%Y-%m-%dT%H:%M:%SZ`, `phase`,
   all 11 `phases` at `{status:"pending"}`, empty `units`/`checkpoints`, empty
   `links`). Append the `run_created` event. Write `STATUS.md`.
5. **Read `RECOVERY.md`.** Resolve each repo's test/lint/migration/MR
   conventions from its `CLAUDE.md`/`AGENTS.md` when you reach it — never assume.
6. **Arm the heartbeat.** `ScheduleWakeup` 1200–1800s, prompt: *"check agents,
   recover per RECOVERY.md, continue per state.json."* Re-arm it each phase. Do
   NOT use wakeups for streaming — use `Monitor` when there is a pollable signal.
7. **`TaskCreate`** one task per phase (and, once planned, one per shipping
   unit); `TaskUpdate` at every transition.

### Conductor duties after EVERY phase (non-negotiable)

- **Persist** the workflow's return into the phase's `artifacts/` dir when it
  isn't already on disk (workflow agents write most artifacts themselves; you
  fill gaps and record paths).
- **Atomic-rewrite `state.json`** — write the full document to
  `<session_dir>/state.json.tmp`, then `mv` it into place (never edit in place;
  a control plane may be reading). Update `updated_at`, the phase entry
  (`status`, `started_at`/`ended_at`, `workflow_run_id`, exhaustive `artifacts`),
  `units[]`, and the advisory `phase`.
- **Regenerate `STATUS.md`** (same cadence; render per state-format §5).
- **`TaskUpdate`** phase/unit status.
- **Stamp timings** from real `date -u +%Y-%m-%dT%H:%M:%SZ`.
- **Append the conductor's events** (below) and post ONE milestone line to chat.

**Events you (conductor) emit:** `run_created`, `phase_started`, `phase_done`,
`phase_failed`, `checkpoint_asked`, `checkpoint_answered`, `report_written`,
`recovery_performed`. Everything unit/finding-level (`unit_started`,
`unit_codex_review`, `unit_pushed`, `mr_created`, `finding_confirmed`,
`fix_applied`, `verify_state`, `artifact_written`) is emitted by the agents
INSIDE the workflows — do not double-write those.

## 1. Pipeline overview

| # | Phase key | Script (`workflows/…` unless noted) | Consumes → Produces |
|---|---|---|---|
| — | `triage` | conductor-inline Agent (haiku) — **not** a Workflow | task_text → `artifacts/intent/triage.json` |
| 1 | `research` | `research.workflow.js` | task_text (+ intent) → `artifacts/research/research.md` |
| 2 | `plan_draft` | `plan-draft.workflow.js` | intent.md + research.md → `artifacts/plans/*` + open_questions |
| 3 | `plan_finalize` | `plan-finalize.workflow.js` | plans/* + answers.md → `artifacts/plan/plan.md` + `dag.json` + `selection.json`; `units[]` |
| 4 | `review_plan` ∥ `risk` | `../review-panel/panel.workflow.js` (plan) ∥ `risk.workflow.js` | plan.md → `review-plan/findings.json` ∥ `risk/risk.md` + dag.json risk annotations |
| — | plan amend | conductor-dispatched Agent — **not** a Workflow | confirmed plan findings + risk → edits plan.md/dag.json |
| 5 | `build` | `build.workflow.js` | full dag.json units → per-unit `build/unit-<id>.json`, pushed branches + MRs |
| 6 | `review_code` ∥ `verify` | `../review-panel/panel.workflow.js` (code) ∥ `verify.workflow.js` | pushed diffs → `review-code/findings.json` ∥ local integration + `verify/verification.md` |
| 7 | `fix` | `fix.workflow.js` | confirmed+plausible findings + verify failures → fixes on owning branches, rebuilt integration |
| 8 | `report` | `/work-summary` skill | whole session store → `artifacts/report/launch-report.html` |

Every workflow is **artifact-idempotent** (it probes its own artifacts dir and
skips finished stages), so re-running any phase after an interruption is safe
and fast — with ONE deliberate exception: `verify` always re-runs (it has no
probe/skip step), because re-verification is the whole point after a crash or a
fix. All other workflows probe-and-skip; `verify` rebuilds the integration
branch and re-runs every scenario every time. Every workflow returns
`{status:'bad_input', error}` on a malformed arg instead of throwing — treat
that as a conductor bug and fix the arg.

## 2. Triage (conductor-inline)

ONE cheap Agent call — no workflow:

```
Agent({ subagent_type: "general-purpose", model: "haiku",
  description: "factory triage",
  prompt: "<task_text>. Classify: (a) trivial — implementable in ≤~50 lines, no
    design fork, no schema/API/migration change; if unsure it is NOT trivial.
    (b) user_facing — does it change UI/UX a person sees? Return JSON
    {trivial:bool, user_facing:bool, reason:string}." })
```

Persist the JSON return to `artifacts/intent/triage.json`; record the `triage`
phase (no `workflow_run_id` — it isn't a workflow). `user_facing` from here
feeds `research`, `plan-draft`, and `plan-finalize` as `user_facing`.

**Trivial path** (skip research, sharpen, planning, risk):
1. Construct ONE unit inline — `{id:"u1", repo, dir:"<abs checkout>",
   branch:"ben/<feature_slug>", base:"<repo default branch>", deps:[],
   contract:"<the task, self-contained>", notes_for_dependents:""}` — write it
   to `state.json.units` and to `artifacts/plan/dag.json` (`units:[…],
   crosschecks:[], settled:[]`).
2. `build` workflow with that single unit — use the §7 arg shape (`session_dir`,
   `scratch_dir`, `units:[the unit above]`); same per-unit codex review gate.
3. **Slim** code panel — the §8 code-mode arg shape: `mode:"code"`, one target
   `{key:"u1-<repo>", dir, base:"origin/<base>", head:"origin/<branch>"}`,
   `lenses:["correctness","tests","cruft"]`, `session_dir`.
4. If `user_facing`: ONE `claude-ui-test` Agent (screenshot + smoke of the
   change) so the report's screenshot/test-locally sections hold.
5. If the slim panel returns confirmed findings, run `fix` (single repo) before
   reporting.
6. `report`.

Otherwise continue to the full pipeline.

## 3. Sharpen ⇄ research loop (conductor-owned)

Workflow agents can't ask the user — sharpening is yours. Soft cap **≤3 loops**,
then proceed with documented assumptions.

- **Research (ground / re-focus):**
  ```
  Workflow({ scriptPath: "<$HOME>/.claude/skills/factory/workflows/research.workflow.js",
    args: { session_dir, task_text: "<raw description>",
            intent_file: "<session_dir>/artifacts/intent/intent.md",   // OMIT until intent.md exists
            user_facing: <triage.user_facing>,
            focus: "<what a re-loop must dig into>" } })              // OMIT on the first pass
  ```
  `focus` is what forces a re-research (a bare re-run with an existing
  `research.md` and no `focus` short-circuits). `research` takes **no
  `codex_model`** — it is pure Claude.
- **Sharpen:** `AskUserQuestion` rounds — each question carries a *why it
  matters* and a *suggested default*. Two conductor-written artifacts per round:
  (a) append a dated section to
  **`<session_dir>/artifacts/intent/sharpen-qa.md`** recording every question
  asked (with its why-it-matters and suggested default) and the human's answer
  **verbatim** — this is the durable Q&A lineage, never just prose; (b)
  synthesize those answers into **`intent.md`** (Goal / Success criteria / In
  scope / Out of scope / Assumptions) at
  `<session_dir>/artifacts/intent/intent.md`.
- Loop: research may run first to ground the questions, then re-run with a
  `focus` if the answers change what to look for.

Artifacts this phase (conductor-written): `artifacts/intent/sharpen-qa.md`,
`artifacts/intent/intent.md`; the research workflow's agents write
`artifacts/research/research.md`. Record `research` phase.

## 4. Plan draft → checkpoint → finalize

**Draft:**
```
Workflow({ scriptPath: "<$HOME>/.claude/skills/factory/workflows/plan-draft.workflow.js",
  args: { session_dir, user_facing: <bool>, codex_model: "<override>" } })   // codex_model optional
```
Reads `intent.md` + `research.md` from the session dir (do NOT pass them as
args). Returns `{status, open_questions:[{question, why, suggested_default,
source}], summaries:{claude, codex}}`. The `summaries` may be **empty** on a
full-cache resume — never rely on them; the durable truth is the files under
`artifacts/plans/`. Record `plan_draft`; its `artifacts` list is every file the
agents wrote in `plans/` (drafts + critiques), and later grows to include
`answers.md` and the v2 revisions (they belong to `plan_draft`'s dir).

**Checkpoint — plan questions (BOTH modes, always if `open_questions` is
non-empty):** `AskUserQuestion` (batched, each with its suggested default).
Write the answers **verbatim and dated** to
`<session_dir>/artifacts/plans/answers.md`. Append `answers.md` to
`plan_draft.artifacts`; add a `checkpoints[]` entry (`stage:"plan-questions"`,
`questions:<n>`, `answers_file:"artifacts/plans/answers.md"`); emit
`checkpoint_asked` then `checkpoint_answered`. If there are no questions, do NOT
create `answers.md` — `plan-finalize` keys off its absence.

> Sharpen answers live in `intent.md`; `answers.md` is exclusively the
> plan-draft open-question answers that `plan-finalize` consumes (absent when
> there were none).

**Finalize:**
```
Workflow({ scriptPath: "<$HOME>/.claude/skills/factory/workflows/plan-finalize.workflow.js",
  args: { session_dir, user_facing: <bool>, codex_model: "<override>" } })   // codex_model optional
```
Reads `plans/*`, `intent.md`, and `answers.md` (if present) from the session
dir. Returns `{status, chosen, rationale, units:[{id,repo,dir,branch,base,deps}],
crosschecks:[], settled:[]}`. The returned `units` are the **lite** shape — copy
them into `state.json.units` (add `status:"pending"`). `selection.json` makes
`chosen`/`rationale` resume-durable. Record `plan_finalize` (artifacts `plan.md`,
`dag.json`, `selection.json`). Create the per-unit tasks now.

## 5. Plan panel ∥ risk (concurrent)

Launch **both in the same message** — they run in parallel and neither blocks;
collect both before amending. Both are read-only over `plan.md`; only `risk`
writes (it annotates `dag.json` in place and writes `risk.md`), so there is no
write conflict.

```
Workflow({ scriptPath: "<$HOME>/.claude/skills/review-panel/panel.workflow.js",
  args: {
    mode: "plan",
    targets: [{ key: "plan", path: "<session_dir>/artifacts/plan/plan.md", context: "final selected plan" }],
    focus: [ /* your judgment: plan sections touching migrations, auth, money, data backfills, cross-repo ordering */ ],
    context_files: ["<session_dir>/artifacts/intent/intent.md", "<session_dir>/artifacts/research/research.md"],
    settled: [ /* ...dag.json settled, plus the decisions the human's answers locked in */ ],
    refuters: 2,
    session_dir,
  } })
Workflow({ scriptPath: "<$HOME>/.claude/skills/factory/workflows/risk.workflow.js",
  args: { session_dir } })                                            // session_dir is its ONLY arg
```

- Plan panel returns `{confirmed, plausible, refuted_count, raw_count,
  deduped_count}` and writes `review-plan/findings.json`. Record `review_plan`.
- Risk returns `{status, overall_risk, deploy_order, rollback_summary,
  watch_areas, focus}` and merges per-unit `risk`/`watch` into `dag.json`.
  **Keep `risk.focus`** — it feeds the CODE panel's `focus`. Record `risk`.

## 6. Plan amend (conductor-dispatched agent)

Dispatch ONE agent (not a workflow) to apply the plan panel's **CONFIRMED**
findings + risk mitigations to `plan.md` and `dag.json`, recording each change
under a `## Amendment log` section in `plan.md`. It edits in place; the pre-amend
plan is still reconstructable from the v2 files + `selection.json`.

After amend, **re-read `dag.json`** — its `units`, `crosschecks`, `settled`, and
per-unit contracts are now authoritative for build. If the unit set changed,
update `state.json.units` (lite shape) to match.

**Checkpointed mode only:** present the amended plan and pause. Add a
`checkpoints[]` entry (`stage:"plan-approval"`), set the phase you pause in to
`paused`, emit `checkpoint_asked`/`checkpoint_answered`. Autonomous mode does not
pause here.

Plan amend has no phase key of its own — it sits between `review_plan`/`risk`
and `build`.

## 7. Build

Read the **full** units from `dag.json` (id, repo, dir, branch, base, deps,
`contract`, `notes_for_dependents`) — the lite `plan-finalize` return omits the
contracts, and build needs them.

```
Workflow({ scriptPath: "<$HOME>/.claude/skills/factory/workflows/build.workflow.js",
  args: {
    session_dir,
    scratch_dir: "<abs scratch dir outside every repo>",   // worktrees land at <scratch_dir>/wt-<unit id>
    units: [ /* full dag.json units */ ],
    already_pushed: [],                                     // recovery: ids of units a prior run already pushed
    settled: [ /* dag.json settled */ ],
    codex_model: "<override>",                              // optional
  } })
```

The workflow launches each unit's build agent the instant its deps reach
`pushed`, in its own worktree; independent units run concurrently, stacked units
sequentially. Per unit: implement → **inline codex adversarial review** →
address/overrule → repo test+lint gates → commit → push → MR/PR →
`build/unit-<id>.json`. Returns `{status:'done'|'partial', results:[{id, status,
branch, mr_url, checks, codex_review, overrules, notes_for_dependents,
detail}]}`; a unit blocked by a failed parent comes back `blocked-by-parent`.
`codex_review` may read `"unavailable: …"` — surface that loudly (the code panel
still covers the diff), but do NOT treat it as a build failure.

Update `state.json.units` from `results` (and from the agents' events/`unit-*.json`
mid-phase at each heartbeat, so the store stays live). Record `build`.

## 8. Code panel ∥ verify (concurrent)

Launch **both in the same message**; collect both before fix. The panel reads
pushed refs; verify builds a local-only integration branch — neither pushes, so
they are safe together.

**Code panel** — one target per **pushed** unit (its own incremental diff):
```
Workflow({ scriptPath: "<$HOME>/.claude/skills/review-panel/panel.workflow.js",
  args: {
    mode: "code",
    targets: [ /* per pushed unit u: */
      { key: "<u.id>-<u.repo>", dir: "<u.dir>", base: "origin/<u.base>", head: "origin/<u.branch>", context: "<one line>" } ],
    focus: [ /* ...risk.focus */ ],
    crosschecks: [ /* per dag.json crosscheck string: {key:"xcheck-<n>", prompt:"<the crosscheck, naming the two diffs it correlates>"} */ ],
    settled: [ /* ...dag.json settled + the human's locked answers */ ],
    context_files: ["<session_dir>/artifacts/plan/plan.md"],
    refuters: 2,
    session_dir,
  } })
```
Returns `{confirmed, plausible, …}`, writes `review-code/findings.json`. Record
`review_code`.

**Verify** — browser check over a local integration branch:
```
Workflow({ scriptPath: "<$HOME>/.claude/skills/factory/workflows/verify.workflow.js",
  args: {
    session_dir,
    units: [ /* state.json units, the pushed ones */ ],
    scenarios: [ {
      name: "homepage",                     // REQUIRED, /^[a-z0-9-]+$/, UNIQUE across scenarios
      urls: ["http://…"],                   // REQUIRED, non-empty
      seed_script: "#!/bin/bash …",         // optional; run from tmp/, never committed
      assertions: ["…"] } ],                // REQUIRED, non-empty
    integration_repo_dir: "<abs dir of the ONE repo whose app is under browser test>",
    login_recipe: "<verbatim login steps>", // optional; RECOVERY.md has the dev-SSO mint
    feature_slug,                           // REQUIRED, /^[a-z0-9-]+$/ — names local/<slug>-integration
  } })
```
You compose `scenarios` from `intent.md` success criteria + `research.md` "how to
test" + UI vocab. Returns `{status:'done', integration:{built,migrated,smoke},
scenarios:[{name,pass,detail,screenshots,console}], console_findings}`. **Scenario
failures do NOT fail the workflow** — they feed fix. Record `verify`.

## 9. Fix

**Checkpointed mode only:** present the consolidated findings and pause first
(`checkpoints[]` `stage:"fix-approval"`; the `fix` phase status is `paused` until
approved; emit `checkpoint_asked`/`checkpoint_answered`).

```
Workflow({ scriptPath: "<$HOME>/.claude/skills/factory/workflows/fix.workflow.js",
  args: {
    session_dir,
    findings: [ /* code-panel confirmed + plausible, PLUS each verify scenario
                   failure rendered as a finding {file:"<integration_repo_dir>/", title:"verify: <name> failed",
                   detail:"<failure>", severity:"major"} so broken scenarios get fixed too — the
                   absolute integration-repo dir (trailing slash) routes the finding to that repo's
                   fix agent, which diagnoses it rather than overruling it for lack of a file */ ],
    units: [ /* state.json units[] with status pushed only, full shape incl. mr_url */ ],
    integration_repo_dir: "<same repo as verify>",
    feature_slug,
    seed_state1_cmd: "<verbatim seed for manual-test state 1>",   // optional
  } })
```
An **empty `findings` array short-circuits to a done no-op** — not a bad_input.
The workflow fixes each finding on the branch that owns the file, cascades
rebases down each stack, re-gates, `--force-with-lease` pushes, notes the MRs,
rebuilds the local integration branch, and re-seeds state 1. Fixes can come back
`action:'failed'` (a gate stayed red — the fix was dropped, not shipped red).
Returns `{status:'done'|'partial', fixes:[{finding_title, unit, action, reasoning,
commit}], integration_rebuilt, seeded}`. Record `fix`.

## 10. Report

```
Skill({ skill: "work-summary", args: "<session_dir>" })
```
`/work-summary` mines the session store, verifies MR/pipeline state live, writes
`docs/specs/<feature_slug>-work-summary.html`, and **copies it to
`<session_dir>/artifacts/report/launch-report.html`** (with its screenshots). It
will tell you to set `links.report` — only the conductor writes `state.json`, so
you set `links.report = "artifacts/report/launch-report.html"`, flip `report` to
`done`, and emit `report_written`. Then post the final chat message: ELI5, MR/PR
links, safe merge order, and what is left for the human. Do NOT paste the whole
report into chat.

## Codex policy

`plan-draft` and `plan-finalize` require codex as the independent second model.
If it is missing/unauthenticated/model-unavailable, the workflow returns
`{status:'codex-unavailable', stage, detail}` — **pause the phase, surface
`detail` verbatim** (it is one actionable line, e.g. *"model gpt-5.6-sol not
available on this account — pass codex_model override or wait for GA"*), set the
phase `failed`, emit `phase_failed`, and wait for the human. Never let Claude
ghost-write codex's deliverable. In `build`, codex is a per-unit gate, not a hard
stop: an unavailable codex leaves `codex_review:"unavailable: …"` and the unit
still ships — the code panel reviews every diff regardless. `codex_model` is the
escape hatch on `plan-draft`/`plan-finalize`/`build` (e.g. `"gpt-5.5"`); pass it
through only if the human overrides. See `references/codex-job.md`.

## Recovery quick-reference

On any agent/workflow death, stall, or fresh session, follow `RECOVERY.md`. The
one-paragraph version: **read `state.json`** to see where the run was → **git
survey** every unit's lane (local vs `origin/<branch>` SHAs: pushed /
committed-not-pushed / uncommitted / absent) → **`TaskStop` presumed-dead
agents** before relaunching (a suspended agent can resurrect and race its
replacement) → **re-run the current phase's workflow**, which skips completed
stages via its own artifact probe (except `verify`, which by design always
re-runs). For `build`, pass only the unfinished `units` and put already-
satisfied ids in `already_pushed` so their lanes start immediately and are
never rebuilt. For `fix`, re-pass the FULL pushed-units list (routing needs
every unit's `dir`; `fix` has no `already_pushed`) and trim `findings` to those
not yet actioned in `artifacts/fix/fixes.json` instead. Same-session interruptions MAY reuse the
Workflow journal via `resumeFromRunId` (from the stored `workflow_run_id`), but
correctness never depends on it — artifact idempotence + git survey is the real
recovery. Emit `recovery_performed`, update `state.json`/`STATUS.md`, re-arm the
heartbeat.

## Concurrency & house rules

- **One git writer per working tree, ever.** Parallel lanes are different repos
  or isolated worktrees only; stacked branches in one repo are sequential.
- Launch each concurrent pair (plan-panel ∥ risk, code-panel ∥ verify) as two
  `Workflow` calls **in the same assistant message**, and do not proceed until
  both have returned.
- `state.json` is conductor-only and always written tmp-then-`mv`. `STATUS.md`
  regenerates on every rewrite; during a concurrent window its header may render
  `**Phase:** review_code ∥ verify`.
- The singular advisory `phase` field holds the pipeline-latest of a running
  pair — `risk` while `review_plan ∥ risk`, `verify` while `review_code ∥
  verify`; `phases.<name>.status` is the authoritative per-phase view.
- Timestamps are always real (`date -u +%Y-%m-%dT%H:%M:%SZ`); never invent them.
