---
name: feature-pipeline
description: Run a task folder (task.md + meta.json) through the full feature pipeline — triage → sharpen → research → dual plans (codex + claude) → critique → select → implement → review panel → real verify loop → ship → feedback. TRIGGER when the user types /feature-pipeline (with a task-folder path, "new <intent>", "sweep", "status", or answers for a paused task), or asks to run/resume/queue a feature-pipeline task.
---

# /feature-pipeline — task-folder feature pipeline (front door)

Every task lives in its own folder (default root: `.feature-pipeline/` at the
repo root of the current project). The folder is the single source of truth:
intent in `task.md`, config in `meta.json`, every pipeline artifact beside them.
Full contract: `TASK_FORMAT.md` next to this file.

The heavy lifting happens in the workflow script that ships with this skill:
`~/.claude/skills/feature-pipeline/feature-pipeline.js` (expand `~` to the real
`$HOME` before passing it as `scriptPath` — the Workflow tool does not expand it).

**This skill is the ONLY writer of `status.json`.** The workflow returns a
status; you persist it. Timestamps come from real `date -u +%Y-%m-%dT%H:%M:%SZ`.

## 1. Parse `$ARGUMENTS`

- **`new <intent…>`** → scaffold a task (section 2), then run it (section 3).
- **A path** (contains `/` or names an existing directory) → run/resume that
  task folder (section 3).
- **`status`** → print a table of every task under the tasks root: slug,
  status, stage, attempts, nextAttemptAt, one-line intent. Stop.
- **`sweep` or empty** → pick the ONE most actionable task and run it
  (priority order):
  1. `needs-input` where `answers.md` exists and is newer than `questions.md`
  2. `retrying` whose `nextAttemptAt` has passed
  3. `pending` (oldest first)
  If none: print the status table instead and mention that `blocked` tasks
  need a human edit (section 5). Never run more than one task per invocation.
- **Extra prose alongside a path** (e.g. `/feature-pipeline <path> — answers: …`)
  → treat the prose as answers: append it verbatim to that task's `answers.md`
  (with a `## <ISO date>` header), then run the task.

## 2. Scaffolding (`new`)

1. Slug: kebab-case, ≤40 chars, from the intent (e.g. `progress-bar-batch-funding`).
2. Create `<tasks-root>/<slug>/`. If the tasks root is new, also write
   `<tasks-root>/.gitignore` containing `*` so nothing leaks into the repo.
3. Write `task.md` = the user's intent verbatim (plus any links/context given).
4. Write `meta.json`. Infer `verify` from the repo's own docs (CLAUDE.md /
   TESTING.md / package.json scripts) — in the YC monorepo the default is
   `"yc test local-changes && yc check-all local-changes"`. If you cannot infer
   a verify command with confidence, ask the user for one before launching —
   a wrong verify wastes an entire run. Only set `complexity`/`userFacing` if
   the user declared them; otherwise leave them out and let triage decide.
5. Write `status.json`: `{"status":"pending","attempts":0,"failureSignatures":[],"history":[…]}`.
6. Echo the folder path and the chosen verify command, then run it.

## 3. Run / resume a task

1. Read `task.md`, `meta.json`, `answers.md` (if any), `status.json`, and
   `<tasks-root>/config.json` (if any). Refuse politely if `task.md` or
   `meta.json`'s `verify` is missing.
2. Guards:
   - `done` → say so; re-run only if the user explicitly insists.
   - `blocked` → require a human touch first (section 5).
   - `needs-input` with no new `answers.md` → show `questions.md` and stop;
     tell the user they can answer right here in chat and you'll record it.
3. Update `status.json`: `status: "in-progress"` (keep `attempts`,
   `failureSignatures`, bump `updatedAt`, append to `history`).
4. Launch (single call; it runs in the background and you get a
   task-notification when it finishes — watch live via `/workflows`):

   ```
   Workflow({
     scriptPath: "<$HOME>/.claude/skills/feature-pipeline/feature-pipeline.js",
     args: {
       taskDir:  "<absolute task folder path>",
       task:     "<task.md contents>",
       meta:     <parsed meta.json>,
       answers:  "<answers.md contents or ''>",
       config:   <parsed tasks-root config.json or {}>,
       attempts: <status.json attempts>,
       failureSignatures: <status.json failureSignatures>,
     },
   })
   ```

5. Tell the user it's running and that the pipeline may pause with questions.
   Do not poll — wait for the completion notification.

## 4. On completion — persist status, then report

Map the workflow's returned `status` (always carry `attempts` and
`failureSignatures` back into `status.json`, bump `updatedAt`, append history):

- **`done`** → `status.json`: `"done"`, `shipped`, `mrUrl`, `commit`. Report by
  pasting `summary.md` (it's the designed handoff: ELI5, DB changes,
  screenshots, try-it links), plus the MR link and `proof.md` path. If shipped
  and the user wants CI babysat, suggest `/watch-pipeline`.
- **`needs-input`** → `status.json`: `"needs-input"`, `stage`. Present
  `questions.md` verbatim and say: answer in chat (you'll write `answers.md`
  and resume) or edit `answers.md` directly and re-run `/feature-pipeline <path>`.
- **`set-aside`** (flake / environment-unfixable / codex-unavailable) →
  `status.json`: `"retrying"` with
  `nextAttemptAt = now + backoffMinutes × 2^(setAsideCount)` (default base 30m,
  cap 8h; increment `setAsideCount`). Report the reason and when it becomes
  eligible — a later `sweep` auto-resumes it.
  For reason **`codex-unavailable`**: relay the `detail` verbatim (it names the
  exact fix — install the codex CLI or `codex login`) and tell the user that
  once codex is fixed, `/feature-pipeline <path>` resumes immediately at the
  stage that failed (no need to wait out the backoff) — all completed
  artifacts are preserved.
- **`blocked`** → `status.json`: `"blocked"`, `reason`. Show the rescue
  strategy from `rescue.md` and what a human must decide.
- **`bad_input`** → don't change status; fix the reported problem (usually
  `meta.json`) and offer to relaunch.

## 5. Resuming a `blocked` task

Only on an explicit `/feature-pipeline <path>` after the human has changed
something (edited `task.md`/`answers.md`, adjusted the plan, or acted on
`rescue.md`): reset `attempts` to 0 and `failureSignatures` to `[]` in
`status.json` (fresh cap — the rescue strategy is already on disk for the fix
agents), set `"in-progress"`, and launch as in section 3. If nothing was
touched since it blocked, say what `rescue.md` recommends and stop.

## 6. Queueing

To keep a queue draining unattended: `/loop 45m /feature-pipeline sweep`.
Each sweep runs at most one task end-to-end, so the interval paces spend, not
correctness.
