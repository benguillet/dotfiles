# Factory session state store — format contract

This is the control-plane API for `/factory` runs. Every workflow script's
prompts, the conductor (`skills/factory/SKILL.md`), and a future
control-plane web app all read and write this exact shape. **Field names,
enums, and event types below are normative.** Nothing here is prose-only —
every schema has a complete, valid, worked example.

Write access is split by construction, not convention: **Workflow scripts
have no filesystem access.** Only the **conductor** (main agent loop) and the
**agents running inside a workflow** can touch disk. Concretely:

- The **conductor** is the only writer of `state.json` — it persists each
  workflow's return value into `artifacts/`, atomic-rewrites `state.json`,
  and regenerates `STATUS.md`, at every phase boundary and checkpoint.
- **Agents inside workflows** (which do have tools) append their own lines to
  `events.jsonl` and drop their own files under `artifacts/` as they work —
  this keeps the store live mid-phase, not just at phase boundaries.

## 1. Layout

One directory per run, `~/.factory/runs/<run-id>/` (see §6 for the `run-id`
rule and why the store lives outside any repo):

```
~/.factory/runs/2026-07-08-example-feature/
├── state.json          # single source of truth — conductor-owned, atomic rewrite (tmp+rename)
├── events.jsonl         # append-only event log — conductor AND agents append
├── STATUS.md            # human-readable render of state.json, regenerated at milestones
└── artifacts/
    ├── intent/
    │   ├── triage.json          # triage phase output
    │   └── intent.md            # sharpen⇄research loop output
    ├── research/
    │   └── research.md
    ├── plans/
    │   ├── plan.claude.md       # v1 draft, claude
    │   ├── plan.codex.md        # v1 draft, codex
    │   ├── critique-of-claude.md
    │   ├── critique-of-codex.md
    │   ├── critique-ux.md       # user-facing runs only
    │   ├── answers.md           # human answers to open questions
    │   ├── plan.claude.v2.md    # post-critique revision
    │   └── plan.codex.v2.md     # post-critique revision
    ├── plan/
    │   ├── plan.md               # final selected plan (first line: `Chosen: …`)
    │   └── dag.json               # units/crosschecks/settled, extracted from plan.md
    ├── risk/
    │   └── risk.md
    ├── review-plan/
    │   └── findings.json          # review-panel(mode=plan) output
    ├── build/
    │   ├── unit-u1.json            # one file per shipping unit
    │   └── unit-u2.json
    ├── review-code/
    │   └── findings.json          # review-panel(mode=code) output
    ├── verify/
    │   ├── verification.md
    │   └── screenshots/
    │       └── homepage-01.png
    ├── fix/
    │   └── fixes.json
    └── report/
        └── launch-report.html
```

Each `phases.<name>` key in `state.json` (§2) maps to exactly one
`artifacts/` subdirectory:

| phase key       | artifacts dir            |
|-----------------|---------------------------|
| `triage`        | `artifacts/intent/`        |
| `research`      | `artifacts/research/`      |
| `plan_draft`    | `artifacts/plans/`          |
| `plan_finalize` | `artifacts/plan/`           |
| `review_plan`   | `artifacts/review-plan/`    |
| `risk`          | `artifacts/risk/`            |
| `build`         | `artifacts/build/`           |
| `review_code`   | `artifacts/review-code/`     |
| `verify`        | `artifacts/verify/`           |
| `fix`           | `artifacts/fix/`               |
| `report`        | `artifacts/report/`            |

Note `triage` writes into `intent/` (it shares the directory with the later
`intent.md`, not a `triage/` dir of its own), and that the hyphen/underscore
split is deliberate: phase *keys* in JSON use `_` (valid JS identifiers,
`phases.review_plan.status`), directory *names* on disk use `-`
(`review-plan/`, `review-code/`) to match the rest of this repo's kebab-case
file naming.

## 2. `state.json`

Full worked example (a run mid-`build`, one unit pushed, one still building —
every field populated at least once so the shape is unambiguous; a live
in-flight run would leave unreached fields absent rather than null, exactly
as the `pending` phases and the `building` unit show below):

```json
{
  "run_id": "2026-07-08-example-feature",
  "feature": "Add CSV export to the billing dashboard",
  "mode": "autonomous",
  "created_at": "2026-07-08T18:00:00Z",
  "updated_at": "2026-07-08T19:42:11Z",
  "phase": "build",
  "phases": {
    "triage": {
      "status": "done",
      "started_at": "2026-07-08T18:00:05Z",
      "ended_at": "2026-07-08T18:00:42Z",
      "artifacts": ["artifacts/intent/triage.json"]
    },
    "research": {
      "status": "done",
      "started_at": "2026-07-08T18:00:42Z",
      "ended_at": "2026-07-08T18:14:09Z",
      "workflow_run_id": "wf_res_9f21",
      "artifacts": ["artifacts/research/research.md"]
    },
    "plan_draft": {
      "status": "done",
      "started_at": "2026-07-08T18:14:09Z",
      "ended_at": "2026-07-08T18:41:55Z",
      "workflow_run_id": "wf_pdraft_3a10",
      "artifacts": [
        "artifacts/plans/plan.claude.md",
        "artifacts/plans/plan.codex.md",
        "artifacts/plans/critique-of-claude.md",
        "artifacts/plans/critique-of-codex.md",
        "artifacts/plans/critique-ux.md",
        "artifacts/plans/answers.md",
        "artifacts/plans/plan.claude.v2.md",
        "artifacts/plans/plan.codex.v2.md"
      ]
    },
    "plan_finalize": {
      "status": "done",
      "started_at": "2026-07-08T18:42:10Z",
      "ended_at": "2026-07-08T19:02:31Z",
      "workflow_run_id": "wf_pfinal_77bd",
      "artifacts": ["artifacts/plan/plan.md", "artifacts/plan/dag.json"]
    },
    "review_plan": {
      "status": "done",
      "started_at": "2026-07-08T19:02:31Z",
      "ended_at": "2026-07-08T19:18:47Z",
      "workflow_run_id": "wf_revplan_c001",
      "artifacts": ["artifacts/review-plan/findings.json"]
    },
    "risk": {
      "status": "done",
      "started_at": "2026-07-08T19:02:31Z",
      "ended_at": "2026-07-08T19:16:02Z",
      "workflow_run_id": "wf_risk_e220",
      "artifacts": ["artifacts/risk/risk.md"]
    },
    "build": {
      "status": "running",
      "started_at": "2026-07-08T19:19:00Z",
      "workflow_run_id": "wf_build_10aa",
      "artifacts": []
    },
    "review_code": { "status": "pending" },
    "verify": { "status": "pending" },
    "fix": { "status": "pending" },
    "report": { "status": "pending" }
  },
  "units": [
    {
      "id": "u1",
      "repo": "code",
      "dir": "/Users/ben/Work/yc/code",
      "branch": "ben/csv-export-01-endpoint",
      "base": "master",
      "deps": [],
      "status": "pushed",
      "mr_url": "https://gitlab.com/yc-software/code/-/merge_requests/48213",
      "started_at": "2026-07-08T19:19:00Z",
      "pushed_at": "2026-07-08T19:38:02Z",
      "checks": "green"
    },
    {
      "id": "u2",
      "repo": "code",
      "dir": "/Users/ben/Work/yc/code",
      "branch": "ben/csv-export-02-ui",
      "base": "ben/csv-export-01-endpoint",
      "deps": ["u1"],
      "status": "building",
      "started_at": "2026-07-08T19:40:00Z"
    }
  ],
  "checkpoints": [
    {
      "at": "2026-07-08T18:41:55Z",
      "stage": "plan-questions",
      "questions": 3,
      "answers_file": "artifacts/plans/answers.md"
    }
  ],
  "links": {
    "report": "artifacts/report/launch-report.html"
  }
}
```

(`links.report` is shown populated for illustration of its shape even though
`report` is `pending` in this snapshot — in a real run it is only set once
the report phase actually writes the HTML file, at which point `report`'s
status flips to `done` in the same rewrite.)

### Top-level fields

| field         | type   | notes |
|---------------|--------|-------|
| `run_id`      | string | see §6; immutable for the life of the run |
| `feature`     | string | one-line description, set at kickoff |
| `mode`        | enum   | `autonomous` \| `checkpointed` — chosen by the conductor's one kickoff `AskUserQuestion` (Autonomous/Checkpointed), lowercased |
| `created_at`  | string | RFC 3339 UTC (`date -u +%Y-%m-%dT%H:%M:%SZ`), set once at kickoff |
| `updated_at`  | string | RFC 3339 UTC, set on every conductor rewrite |
| `phase`       | enum   | the conductor's primary/leading phase indicator — advisory, for display; one of the `phases` object's keys (see the concurrency note below) |
| `phases`      | object | see below |
| `units`       | array  | see below; `[]` until `plan_finalize` populates it |
| `checkpoints` | array  | see below; `[]` if the run never paused |
| `links`       | object | cross-cutting pointers not owned by any single phase (currently just `report`; open to more as the control plane grows) |

**Concurrent phases and the singular `phase` field.** Two phase pairs run
concurrently by design: `review_plan` ∥ `risk` and `review_code` ∥ `verify`.
The singular `phase` field is therefore not a complete picture of what's
running — it is the conductor's primary/leading phase indicator, advisory
and for display; **`phases.<name>.status` is the authoritative per-phase
state**, and a consumer that needs "everything running right now" must scan
the `phases` object for `"status": "running"`, never read `phase` alone.
During a concurrent window, `phase` holds the pipeline-order-latest running
phase (`risk` while `review_plan` ∥ `risk`; `verify` while `review_code` ∥
`verify`), and the `STATUS.md` header may render both (see §5).

### `phases.<name>`

Keys are exactly the 11 phase names shown in the example above: `triage`,
`research`, `plan_draft`, `plan_finalize`, `review_plan`, `risk`, `build`,
`review_code`, `verify`, `fix`, `report`. A phase entry accumulates fields as
it progresses — a `pending` phase has only `status`; once started it gains
`started_at` (and `workflow_run_id` if it is workflow-backed — `triage` is a
cheap conductor-inline agent, not a `Workflow()` call, so it never has one);
once finished it gains `ended_at` and `artifacts`.

| field             | type            | notes |
|-------------------|-----------------|-------|
| `status`          | enum            | `pending \| running \| done \| failed \| paused` |
| `started_at`       | string          | present once `status` leaves `pending` |
| `ended_at`         | string          | present once `status` reaches `done`/`failed` |
| `workflow_run_id`  | string          | opaque id returned by `Workflow({scriptPath, args})`; present only for workflow-backed phases, once launched. Enables same-session `resumeFromRunId` (never required for correctness — see RECOVERY.md) |
| `artifacts`        | array of string | **exhaustive** — every artifact the phase produced, not a curated subset; paths relative to the session (run) dir, e.g. `"artifacts/research/research.md"`; `[]` while running, populated once `done` |

Attribution for the exhaustive `artifacts` rule follows the §1 phase → dir
mapping: a phase's list is exactly the files of its artifacts dir, so files
that land in that dir later (`answers.md` at the checkpoint, the `plans/`
v2 revisions written during `plan_finalize`'s revise stage) are appended to
the *owning* phase's list — `plan_draft` in both cases — at the conductor
rewrite that records them.

`paused` (phase status) is reached only in Checkpointed mode, at the two
checkpoints beyond plan-draft's open-questions gate (see `checkpoints`
below and spec §"Session state store" / §"Checkpointed mode").

### `units[]`

One entry per shipping unit, populated by `plan_finalize` (from
`dag.json`) and updated by the `build` phase's agents as they progress
through implement → codex review → gates → push → MR/PR.

| field         | type   | notes |
|---------------|--------|-------|
| `id`          | string | e.g. `u1`; matches the id used in `dag.json` and `artifacts/build/unit-<id>.json` |
| `repo`        | string | short repo name, e.g. `code` |
| `dir`         | string | absolute checkout path, e.g. `/Users/ben/Work/yc/code` |
| `branch`      | string | this unit's branch |
| `base`        | string | parent branch/ref this unit targets (its own branch for the first unit in a stack, or the parent unit's branch) |
| `deps`        | array of string | ids of units that must reach `pushed` first; `[]` if none |
| `status`      | enum   | `pending \| building \| codex-review \| gates \| pushed \| failed \| blocked-by-parent` |
| `mr_url`      | string | present once the MR/PR is created |
| `started_at`  | string | present once `status` leaves `pending` |
| `pushed_at`   | string | present once `status` reaches `pushed` |
| `checks`      | string | free-text CI summary, e.g. `"green"`, `"red"`, `"pending"` — not a closed enum |

`unit.status` meanings: `building` = implementing; `codex-review` = the
per-unit adversarial codex gate is running; `gates` = repo test/lint check
gate running; `pushed` = committed, pushed, MR/PR open; `blocked-by-parent`
= a dependency never reached `pushed` so this unit was skipped; `failed` =
the build agent died after retries.

Per-unit build detail that is useful for debugging but not needed by a
session-card view — `codex_review` outcome text, `overrules` (findings the
build agent explicitly overruled, with reasoning), `notes_for_dependents` —
lives in `artifacts/build/unit-<id>.json`, not in this array. `units[]` is
the control-plane summary; the artifact file is the full record.

### `checkpoints[]`

One entry per human pause. There are three known checkpoint moments in the
pipeline: the plan-draft open-questions gate (always, if there are any
questions — `stage: "plan-questions"`, as in the example above), and, in
Checkpointed mode only, final-plan approval after plan-amend and confirmed-
findings approval before fix. `stage` is a short free-text slug, not a
closed enum — `plan-questions` is the one literal value used by existing
prompts; the other two moments are free to use whatever slug the conductor
prompt assigns (e.g. `plan-approval`, `fix-approval`) as long as it's
appended consistently by the same phase in every run.

| field          | type    | notes |
|----------------|---------|-------|
| `at`           | string  | RFC 3339 UTC timestamp the checkpoint was raised |
| `stage`        | string  | which checkpoint moment, see above |
| `questions`    | integer | number of open questions presented |
| `answers_file` | string  | path relative to the run dir where the human's answers were recorded |

### `links`

Free-form map of paths the control plane surfaces outside the per-phase
`artifacts` lists. Currently one key: `report` → the copied
`launch-report.html` path, set by the conductor when the `report` phase
completes (see spec: "ALSO copy the report to
`<session_dir>/artifacts/report/launch-report.html` and set `links.report`
in `state.json`").

### Additional state examples

The main example above shows `done`, `running`, and `pending` phases and
`pushed`/`building` units. The remaining enum values, concretely — first
two `phases.<name>` entries (a `failed` workflow-backed phase, whose
failure detail lives in the corresponding `phase_failed` event in
`events.jsonl` rather than in `state.json`; and a `paused` phase, a
Checkpointed-mode run waiting on human approval of confirmed findings
before fixing):

```json
{
  "review_plan": {
    "status": "failed",
    "started_at": "2026-07-08T19:02:31Z",
    "ended_at": "2026-07-08T19:05:10Z",
    "workflow_run_id": "wf_revplan_c001",
    "artifacts": []
  },
  "fix": {
    "status": "paused",
    "started_at": "2026-07-08T20:24:10Z"
  }
}
```

And two `units[]` entries (one mid codex adversarial review, one whose
build agent died after retries — `failed` units keep whatever fields they
had earned when they failed, here a red check gate):

```json
[
  {
    "id": "u3",
    "repo": "paxel",
    "dir": "/Users/ben/Work/yc/paxel",
    "branch": "ben/csv-export-03-worker",
    "base": "main",
    "deps": ["u1"],
    "status": "codex-review",
    "started_at": "2026-07-08T19:52:00Z"
  },
  {
    "id": "u4",
    "repo": "code",
    "dir": "/Users/ben/Work/yc/code",
    "branch": "ben/csv-export-04-emails",
    "base": "ben/csv-export-02-ui",
    "deps": ["u2"],
    "status": "failed",
    "started_at": "2026-07-08T20:10:00Z",
    "checks": "red"
  }
]
```

## 3. Atomic write rule (conductor-only)

The conductor is the only writer of `state.json`, but the control plane may
be reading it concurrently, so every rewrite is atomic: write the full new
document to a temp file in the same directory, then rename it into place —
never write `state.json` in place.

```bash
# conductor, on every phase boundary / checkpoint / milestone
cat > ~/.factory/runs/<run-id>/state.json.tmp <<'EOF'
{ ...new state.json contents... }
EOF
mv ~/.factory/runs/<run-id>/state.json.tmp ~/.factory/runs/<run-id>/state.json
```

`mv` within the same directory/filesystem is an atomic rename — a
concurrent reader always sees either the fully-old or fully-new file, never
a half-written one. This is the entire recipe: no locking, no versioning,
just tmp-then-rename.

## 4. `events.jsonl`

Append-only, one JSON object per line, written by BOTH the conductor and
agents running inside workflows (see the writer split at the top of this
document). Never rewritten or reordered — this is what makes it safe for
concurrent appenders and what makes it directly `sqlite3 .import`-able
later (one line = one future row).

Schema per line: `{ts, type, by, unit?, detail?}`.

| field    | type   | notes |
|----------|--------|-------|
| `ts`     | string | RFC 3339 UTC, from real `date -u +%Y-%m-%dT%H:%M:%SZ` — never `Date.now()`/`new Date()` (workflow scripts don't have those; agents shell out for the real clock) |
| `type`   | enum   | one of the canonical types below |
| `by`     | string | `conductor` \| `agent:<label>` (label matches the agent's `label` in its `Workflow()`/dispatch call, e.g. `agent:build:u1`, `agent:review-code:refuter-2`) |
| `unit`   | string | optional; the unit id this event concerns, when applicable |
| `detail` | string | optional; short free text, under 120 chars, single line |

Canonical `type` list (exhaustive — do not invent new types without
updating this file first, since the control plane matches on these
strings): `run_created`, `phase_started`, `phase_done`, `phase_failed`,
`checkpoint_asked`, `checkpoint_answered`, `unit_started`,
`unit_codex_review`, `unit_pushed`, `mr_created`, `finding_confirmed`,
`fix_applied`, `verify_state`, `report_written`, `recovery_performed`.

By convention (not mechanically enforced — workflow scripts have no
filesystem access, so any event emitted *during* a workflow's run is
necessarily written by one of its agents, not by the workflow script's own
control flow): the **conductor** emits the run/phase/checkpoint-level
events (`run_created`, `phase_started`, `phase_done`, `phase_failed`,
`checkpoint_asked`, `checkpoint_answered`, `report_written`,
`recovery_performed`); **agents inside workflows** emit the unit/finding-
level events as they do the work (`unit_started`, `unit_codex_review`,
`unit_pushed`, `mr_created`, `finding_confirmed`, `fix_applied`,
`verify_state`).

Full worked example — one run's log from kickoff through report, in order
(a real mid-run log would simply stop wherever the run currently is; this
shows every canonical type at least once):

```jsonl
{"ts":"2026-07-08T18:00:00Z","type":"run_created","by":"conductor","detail":"feature=\"Add CSV export to the billing dashboard\" mode=autonomous"}
{"ts":"2026-07-08T18:00:05Z","type":"phase_started","by":"conductor","detail":"triage"}
{"ts":"2026-07-08T18:00:42Z","type":"phase_done","by":"conductor","detail":"triage: not trivial, user-facing=true"}
{"ts":"2026-07-08T18:00:42Z","type":"phase_started","by":"conductor","detail":"research"}
{"ts":"2026-07-08T18:14:09Z","type":"phase_done","by":"conductor","detail":"research: 4 scouts run"}
{"ts":"2026-07-08T18:14:09Z","type":"phase_started","by":"conductor","detail":"plan_draft"}
{"ts":"2026-07-08T18:41:55Z","type":"checkpoint_asked","by":"conductor","detail":"3 open questions from plan-draft critique"}
{"ts":"2026-07-08T18:42:05Z","type":"checkpoint_answered","by":"conductor","detail":"human answered 3/3, see artifacts/plans/answers.md"}
{"ts":"2026-07-08T18:42:10Z","type":"phase_done","by":"conductor","detail":"plan_draft"}
{"ts":"2026-07-08T18:42:10Z","type":"phase_started","by":"conductor","detail":"plan_finalize"}
{"ts":"2026-07-08T19:02:31Z","type":"phase_done","by":"conductor","detail":"plan_finalize: chosen=merged"}
{"ts":"2026-07-08T19:02:31Z","type":"phase_started","by":"conductor","detail":"review_plan"}
{"ts":"2026-07-08T19:02:31Z","type":"phase_started","by":"conductor","detail":"risk"}
{"ts":"2026-07-08T19:10:03Z","type":"finding_confirmed","by":"agent:review-plan:refuter-1","detail":"plan omits a rollback step for the export index migration"}
{"ts":"2026-07-08T19:16:02Z","type":"phase_done","by":"conductor","detail":"risk: overall_risk=medium"}
{"ts":"2026-07-08T19:18:47Z","type":"phase_done","by":"conductor","detail":"review_plan: 1 confirmed finding"}
{"ts":"2026-07-08T19:19:00Z","type":"phase_started","by":"conductor","detail":"build"}
{"ts":"2026-07-08T19:19:00Z","type":"unit_started","by":"agent:build:u1","unit":"u1","detail":"branch=ben/csv-export-01-endpoint base=master"}
{"ts":"2026-07-08T19:31:40Z","type":"unit_codex_review","by":"agent:build:u1","unit":"u1","detail":"2 findings addressed, 0 overruled"}
{"ts":"2026-07-08T19:38:02Z","type":"unit_pushed","by":"agent:build:u1","unit":"u1","detail":"pushed ben/csv-export-01-endpoint"}
{"ts":"2026-07-08T19:38:15Z","type":"mr_created","by":"agent:build:u1","unit":"u1","detail":"https://gitlab.com/yc-software/code/-/merge_requests/48213"}
{"ts":"2026-07-08T19:40:00Z","type":"unit_started","by":"agent:build:u2","unit":"u2","detail":"branch=ben/csv-export-02-ui base=ben/csv-export-01-endpoint"}
{"ts":"2026-07-08T19:41:30Z","type":"recovery_performed","by":"conductor","detail":"heartbeat found u2's agent dead; git survey showed uncommitted work; relaunched"}
{"ts":"2026-07-08T20:05:12Z","type":"unit_pushed","by":"agent:build:u2","unit":"u2","detail":"pushed ben/csv-export-02-ui"}
{"ts":"2026-07-08T20:05:20Z","type":"mr_created","by":"agent:build:u2","unit":"u2","detail":"https://gitlab.com/yc-software/code/-/merge_requests/48214"}
{"ts":"2026-07-08T20:05:20Z","type":"phase_done","by":"conductor","detail":"build: 2/2 units pushed"}
{"ts":"2026-07-08T20:05:21Z","type":"phase_started","by":"conductor","detail":"review_code"}
{"ts":"2026-07-08T20:05:21Z","type":"phase_started","by":"conductor","detail":"verify"}
{"ts":"2026-07-08T20:22:09Z","type":"finding_confirmed","by":"agent:review-code:refuter-2","unit":"u1","detail":"nil deref in ExportsController#create when account has no billing_profile"}
{"ts":"2026-07-08T20:24:00Z","type":"verify_state","by":"agent:verify:composer","detail":"3/3 scenarios PASS, 0 new console errors"}
{"ts":"2026-07-08T20:24:00Z","type":"phase_done","by":"conductor","detail":"verify"}
{"ts":"2026-07-08T20:24:05Z","type":"phase_done","by":"conductor","detail":"review_code: 1 confirmed finding"}
{"ts":"2026-07-08T20:24:10Z","type":"phase_started","by":"conductor","detail":"fix"}
{"ts":"2026-07-08T20:31:47Z","type":"fix_applied","by":"agent:fix:u1","unit":"u1","detail":"guarded nil billing_profile in ExportsController#create, added spec"}
{"ts":"2026-07-08T20:31:47Z","type":"phase_done","by":"conductor","detail":"fix: 1/1 finding fixed"}
{"ts":"2026-07-08T20:31:48Z","type":"phase_started","by":"conductor","detail":"report"}
{"ts":"2026-07-08T20:34:02Z","type":"report_written","by":"conductor","detail":"artifacts/report/launch-report.html"}
{"ts":"2026-07-08T20:34:02Z","type":"phase_done","by":"conductor","detail":"report"}
```

`phase_failed` doesn't occur in the happy path above; it has the same shape,
e.g. a codex-unavailable plan draft would log:

```jsonl
{"ts":"2026-07-08T18:20:00Z","type":"phase_failed","by":"conductor","detail":"plan_draft: codex-unavailable"}
```

## 5. `STATUS.md`

Human-readable render of `state.json`, regenerated by the conductor at
every `state.json` rewrite (same cadence, never independently stale for
long). Rendering the same example run as §2/§4, snapshotted at
`updated_at`:

```markdown
# Factory run: 2026-07-08-example-feature

**Feature:** Add CSV export to the billing dashboard
**Mode:** autonomous
**Phase:** build
**Started:** 2026-07-08T18:00:00Z

## Phases

| Phase | Status | Elapsed |
|---|---|---|
| triage | done | 37s |
| research | done | 13m27s |
| plan_draft | done | 27m46s |
| plan_finalize | done | 20m21s |
| review_plan | done | 16m16s |
| risk | done | 13m31s |
| build | running | 23m11s (so far) |
| review_code | pending | — |
| verify | pending | — |
| fix | pending | — |
| report | pending | — |

## Units

| Unit | Repo | Branch | State | MR |
|---|---|---|---|---|
| u1 | code | ben/csv-export-01-endpoint | pushed | [!48213](https://gitlab.com/yc-software/code/-/merge_requests/48213) |
| u2 | code | ben/csv-export-02-ui | building | — |

## In flight now

- u2 (code): implementing on `ben/csv-export-02-ui`, depends on u1 (pushed)

## Next

- Finish `build` for u2
- `review_code` + `verify` (run concurrently once `build` finishes)

_Last updated: 2026-07-08T19:42:11Z by conductor_
```

Sections are fixed: run header (feature/mode/phase/started), phase table
(phase/status/elapsed), unit table (unit/repo/branch/state/MR), "in flight
now", "next", and a last-updated stamp. The `**Phase:**` header line renders
from `state.json`'s advisory `phase` field; during a concurrent window (see
§2) it may show both running phases, e.g. `**Phase:** review_code ∥ verify`
— the phase table below it is the authoritative per-phase view either way.
Elapsed is computed from `started_at`/`ended_at` (or "now" for `running`);
this is a *render*, not a second source of truth — if `STATUS.md` and
`state.json` ever disagree, `state.json` wins and `STATUS.md` is simply
stale until the next rewrite.

## 6. Run ID and store root

- **`run_id` = `YYYY-MM-DD-<feature-slug>`** (e.g.
  `2026-07-08-example-feature`), stamped once at kickoff from the real date
  (`date -u +%Y-%m-%d`) plus a kebab-case slug derived from the feature
  description. It never changes for the life of the run — recovery re-uses
  it, it is never regenerated.
- **Store root: `~/.factory/runs/<run_id>/`.** Deliberately global —
  outside any git repo or worktree — because a single run's units can span
  multiple repos/checkouts (e.g. `code` + `paxel`), and a future
  control-plane web app wants exactly one filesystem location to enumerate
  every run regardless of which repos it touched.
- **This store is the control-plane API.** Every workflow prompt in this
  pipeline, the conductor, and the (future) control-plane web app are
  written against the exact shapes in §2–§5. Renaming a field, changing an
  enum value, repurposing a directory, or changing what an event type means
  is a breaking change — treat it like an API version bump, not an
  incidental refactor: update every consumer (workflow prompts, RECOVERY.md,
  the control plane) in the same change.
