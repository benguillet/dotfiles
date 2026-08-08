# feature-pipeline — task folder contract

Tasks root: `.feature-pipeline/` at the repo root (self-gitignored via a
`.gitignore` containing `*`). One folder per task; the folder is the whole
state — delete it and the task never happened.

## Inputs (human-authored)

```
<tasks-root>/<slug>/
  task.md          # the intent, free-form (required)
  meta.json        # per-task config (required)
  answers.md       # appended answers after a needs-input pause (optional)
<tasks-root>/config.json   # shared defaults for every task (optional)
```

### meta.json

```jsonc
{
  "verify": "yc test local-changes && yc check-all local-changes",  // REQUIRED — run for real by the verify stage
  "complexity": "trivial" | "complex",  // optional — skips TRIAGE when declared
  "userFacing": true,                   // optional — gates the UX/IA lenses; triage decides when absent
  "ship": true,                         // optional — commit-only when false/absent (unless config.json says otherwise)
  "plansDir": "docs/plans",            // optional — final plan.md also copied here (committed docs)
  "retries": 3,                         // optional — auto-fix hard cap override
  "branch": "ben/custom-name"          // optional — else branchPrefix + slug
}
```

### config.json (tasks-root defaults; meta.json wins per task)

```jsonc
{
  "retries": 3,
  "ship": false,
  "plansDir": null,
  "branchPrefix": "ben/",
  "gates": ["tests", "conventions"],   // always-on review gates beside correctness
  "backoffMinutes": 30                 // retrying backoff base (skill-side, doubles per set-aside, 8h cap)
}
```

## Statuses (`status.json`, written ONLY by the skill)

```
pending → in-progress → done                     (shipped: true when an MR/PR went out)
              ├→ needs-input   questions.md written; answers.md + re-run resumes
              ├→ retrying      flake / unfixable environment; auto-resumes via sweep after nextAttemptAt
              └→ blocked       fix loop hit the cap or went in circles; rescue.md has the next strategy;
                               human touch + explicit re-run resets the cap
```

Fields: `status`, `stage`, `attempts`, `failureSignatures[]`, `setAsideCount`,
`nextAttemptAt`, `shipped`, `mrUrl`, `commit`, `updatedAt`, `history[]`.

## Pipeline artifacts (stage → file)

| Stage | Artifact |
|---|---|
| 1 TRIAGE | `triage.json` — trivial? user-facing? (skipped if declared in meta.json; trivial jumps to IMPLEMENT) |
| 2 SHARPEN | `intent.md` — or `questions.md` + needs-input |
| 3 WORKFORCE | `workforce.json` — routed scouts, review lenses, network policy |
| 4 RESEARCH | `research.md` — synthesized dossier from the scouts |
| 5 PLAN | `plans/plan.claude.md`, `plans/plan.codex.md` |
| 6 CRITIQUE | `plans/critique-of-claude.md`, `plans/critique-of-codex.md` |
| 6.4 UX/IA | `plans/critique-ux.md` (user-facing only) |
| 6.5 RECONCILE | `plans/resolutions.md` — or `questions.md` + needs-input |
| 7 REVISE | `plans/plan.claude.v2.md`, `plans/plan.codex.v2.md` |
| 8 SELECT | `plan.md` (+ copy into `plansDir` when configured) |
| 8.5 RISK | `risk.md` — advisory score + verification focus |
| 8.6 PROTOTYPE | `prototype.json`, `prototype/` (only when it materially derisks) |
| 9 IMPLEMENT | `implemented.json`, code in the worktree, `screenshots/` |
| 10–11 REVIEW | `review.md` — consolidated verdict, blocking vs advisory |
| 12 VERIFY | `verify.log` (every attempt), `rescue.md` on a terminal block |
| commit/SHIP | commit on the task branch; MR/PR when ship is configured |
| 14 FEEDBACK | `proof.md` (evidence), `summary.md` (ELI5 handoff: DB changes, screenshots, try-it links, MR) |

Resume is artifact-based: a re-run skips any stage whose artifact already
exists (that's how needs-input pauses and retrying pick up where they left
off). To force a stage to re-run, delete its artifact.

## Codex

PLAN / CRITIQUE / REVISE / SELECT shell out to the OpenAI Codex CLI
(`codex exec -s read-only`) for the second, independent model. There is
deliberately no single-model fallback: if `codex` is missing or
unauthenticated, the run fails fast — checked up front in Setup (for any
complex task that hasn't reached `plan.md` yet) and again at each codex stage
— and the task is set aside with reason `codex-unavailable` (persisted status
`retrying`). The report tells you the exact fix
(`npm install -g @openai/codex` / `codex login`); once fixed, re-run
`/feature-pipeline <path>` and artifact-based resume continues from the exact
stage that failed (e.g. claude's plan is kept; only codex's side re-runs).
Codex outputs carry `<!-- author: codex -->` as their first line.
