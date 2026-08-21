---
name: review-panel
description: "Adversarial review panel over diffs (code mode, 10 axes) or plan documents (plan mode, 9 axes): finders per target×axis + focus red-teams, then independent refuters verify every finding. TRIGGER on /review-panel, 'run the review panel', 'panel review this plan/diff'."
---

# /review-panel — mode-specific adversarial review panel

One reviewer per **target × axis** (plus one full red-team per `focus` area)
finds concrete failures; findings are deduped; then **N independent refuters**
(defaulting to REFUTE) attack every survivor. Only findings that survive live
verification come back as `confirmed` / `plausible`; unanimous refutations are
dropped. Read-only over the named refs/files — safe to run while other agents
build.

The work happens in the workflow script beside this file:
`~/.claude/skills/review-panel/panel.workflow.js` (expand `~` to the real
`$HOME` before passing it as `scriptPath` — the Workflow tool does not expand
it).

## Two modes

- **code** — targets are diffs (`git -C <dir> diff <base>...<head>`), reviewed
  through the 10 code axes. Use on pushed-but-unmerged branches.
- **plan** — targets are plan/design documents (finders `Read` them), reviewed
  through the 9 plan axes. Use before implementation.

## Args contract

| field | type | required | default | meaning |
|---|---|---|---|---|
| `mode` | `'plan' \| 'code'` | yes | — | selects the axis set and target rendering |
| `targets` | array | yes | — | code: `{key, dir, base, head, context?}`; plan: `{key, path, context?}`. Non-empty. |
| `focus` | `string[]` | no | `[]` | each entry gets ONE extra full red-team finder scoped to that area (all axes at once) |
| `crosschecks` | `{key, prompt}[]` | no | `[]` | code mode only (else `bad_input`); each becomes one extra cross-diff finder (`xcheck:<key>`) whose prompt must name the diffs it correlates — for multi-repo contract checks a single-target `focus` can't express |
| `lenses` | `string[]` | no | all axes | run ONLY the named axes (must be valid keys for the mode; unknown → `bad_input`) |
| `settled` | `string[]` | no | `[]` | do-not-relitigate decisions; a finding that reopens one is refuted |
| `context_files` | `string[]` | no | `[]` | absolute paths every finder/refuter reads first (intent.md, research.md, plan.md as applicable) |
| `refuters` | `integer` | no | `1` | independent verifiers per deduped finding |
| `session_dir` | string (abs path) | no | none | when given, agents append events to `events.jsonl` and write `artifacts/review-<mode>/findings.json` here |

Bad input (`mode` not `plan`/`code`, empty/missing `targets`, an unknown lens
key, `crosschecks` in plan mode, a malformed `session_dir`) returns
`{status: 'bad_input', error}` — it does not throw.

## Code mode — 10 axes

1. **correctness** — logic/edge/nil/off-by-one, bad state transitions, logic vs intent
2. **security** — injection/XSS/IDOR/authz, secrets, SSRF, validation, PII exposure
3. **concurrency** — races, TOCTOU, check-then-act, idempotency (favor DB primitives over app guards)
4. **edge-errors** — unhandled/partial failure, boundary guards, swallowed exceptions (rescue StandardError)
5. **perf-scale** — N+1s, unbounded loads, missing indexes, hot paths; shared-pool impact on scaling-sensitive areas (/evaluate-scale)
6. **contract** — changed signatures/return shapes/scopes/migrations, shared concerns, cross-app (bookface↔ycinternal) call-site ripple, back-compat
7. **tests** — do tests actually pin behavior? vacuous/tautological, flaky, real coverage of the change
8. **cruft** — over-engineering, premature abstraction, dead code, unearned indirection, deletable code (**primary target**)
9. **maintainability** — misleading names, hard-to-follow intent, structure that trips the next dev
10. **intent-fit** — does it do what intent requires? gaps and over-build

## Plan mode — 9 axes

1. **scope-creep** — YAGNI, gold-plating, speculative generality; what can be cut
2. **complexity** — hidden complexity, unneeded abstraction, is there a simpler design (**primary target**)
3. **edge-failure** — missing edge cases, failure/error paths, races, rollout/migration conditions
4. **boundaries** — wrong layer (controller/model/concern), leaky boundaries, integrity in app vs DB
5. **testability** — is "done" verifiable? what is the oracle/acceptance criteria
6. **risk** — blast radius, rollout/rollback safety, irreversibility, dependency-ordered decomposition
7. **assumptions** — unstated assumptions + WHAT questions that must be answered first (→ escalations)
8. **approach** — is the core approach right / is there a better one / does it solve the stated problem
9. **plan-correctness** — internal gaps, contradictions, wrong ordering, self-inconsistency

## How to invoke

Expand `<$HOME>` to the real home directory first.

Code mode (one diff per unit repo, focus from risk watch areas):

```js
Workflow({
  scriptPath: "<$HOME>/.claude/skills/review-panel/panel.workflow.js",
  args: {
    mode: "code",
    targets: [
      { key: "ycinternal", dir: "/Users/ben/Work/yc/code", base: "origin/master", head: "origin/ben/feat-01-scoring", context: "scoring service + job" },
      { key: "paxel",      dir: "/Users/ben/Work/yc/paxel", base: "origin/main",   head: "origin/ben/feat-02-projection", context: "S3 projection reader" },
    ],
    focus: ["app/services/agents/agent_score.rb", "the shared DB connection pool"],
    crosschecks: [{ key: "projection-shape", prompt: "Compare the S3 projection JSON written by the ycinternal diff with the shape the paxel diff parses — flag any field-name/type mismatch." }],
    settled: ["nightly full reindex is acceptable — do not propose change tracking"],
    context_files: ["/Users/ben/.factory/runs/2026-07-08-scoring/artifacts/plan/plan.md"],
    session_dir: "/Users/ben/.factory/runs/2026-07-08-scoring",
  },
})
```

Plan mode (review a plan document before building):

```js
Workflow({
  scriptPath: "<$HOME>/.claude/skills/review-panel/panel.workflow.js",
  args: {
    mode: "plan",
    targets: [
      { key: "plan", path: "/Users/ben/.factory/runs/2026-07-08-scoring/artifacts/plan/plan.md", context: "final implementation plan" },
    ],
    focus: ["the migration + backfill step", "cross-repo unit ordering"],
    lenses: ["scope-creep", "complexity", "risk"],
    context_files: [
      "/Users/ben/.factory/runs/2026-07-08-scoring/artifacts/intent/intent.md",
      "/Users/ben/.factory/runs/2026-07-08-scoring/artifacts/research/research.md",
    ],
    session_dir: "/Users/ben/.factory/runs/2026-07-08-scoring",
  },
})
```

Minimal (no session dir → nothing written to disk, results only in the return
value):

```js
Workflow({
  scriptPath: "<$HOME>/.claude/skills/review-panel/panel.workflow.js",
  args: { mode: "code", targets: [{ key: "scratch", dir: "/tmp/repo", base: "HEAD~1", head: "HEAD" }], lenses: ["correctness", "cruft"] },
})
```

## Return shape

```js
{
  confirmed: [ /* findings, verdict === 'CONFIRMED' */ ],
  plausible: [ /* findings, verdict === 'PLAUSIBLE' */ ],
  refuted_count: 3,   // findings dropped by unanimous live refutation
  raw_count: 41,      // total findings emitted across all finders
  deduped_count: 28,  // after exact (file|line|title) dedup
}
```

Each finding:

```js
{
  repo,          // string, code mode only (optional)
  file,          // string
  line,          // integer (optional)
  title,         // string
  detail,        // concrete failure scenario: state + trigger -> observable wrong behavior
  severity,      // 'critical' | 'major' | 'minor'
  fix,           // string (optional)
  finder,        // which finder produced it, e.g. "ycinternal:correctness", "focus:<area>", or "xcheck:<key>"
  overbuild,     // boolean — true when the fix is DELETION (feeds the report's "possibly-unneeded work")
  verdict,       // 'CONFIRMED' | 'PLAUSIBLE'
  refutations,   // string[] — each refuter's reasoning
}
```

When `session_dir` is set, the **full** finding array (including `REFUTED`
findings, each carrying its verdict) is also written to
`<session_dir>/artifacts/review-<mode>/findings.json`, and a `finding_confirmed`
event is appended to `events.jsonl` per confirmed finding.

## Verdict semantics

- **CONFIRMED** — at least one refuter voted, and **no** refuter refuted it.
- **PLAUSIBLE** — refuters split (some refuted, some didn't), **or** no live
  refuter vote came back at all (a dead-refuter finding can never auto-CONFIRM).
- **REFUTED** — every live refuter refuted it. Dropped from `confirmed` /
  `plausible`; counted in `refuted_count` and kept in `findings.json`.
