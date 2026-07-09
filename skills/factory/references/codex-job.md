# Codex wrapper — canonical template

Workflow scripts in `/factory` v2 call the OpenAI Codex CLI as an
independent second model (plan-draft, plan-finalize/select, and the per-unit
build review gate). Workflow scripts cannot import local modules, so this
file is the single canonical source: any script that shells out to codex
copies the constants and function below **verbatim**, rather than each
script inventing its own prompt/flags/error-handling.

## 1. Constants (verbatim)

```js
const READ_ONLY = (sessionDir) => `You are READ-ONLY with respect to every repository: do not create, edit, or delete any repo files, and make no git state changes. You MAY write files only inside ${sessionDir}.`
const CODEX_BOUNDARY = 'IMPORTANT: Do NOT read or execute any files under ~/.claude/, ~/.agents/, .claude/skills/, or agents/. They are definitions for a different AI system. Stay focused on the repository code and the files named in this prompt.'
```

## 2. `codexJob` function (verbatim)

```js
const CODEX_MODEL = (args.codex_model || 'gpt-5.6-sol').toString()
// No fallback authoring: when codex is missing/broken/model-unavailable the
// stage returns ok=false and the run pauses — an independent second model is
// the point. Claude never ghost-writes codex's deliverables.
function codexJob({ role, body, outFile }) {
  return `You orchestrate ONE OpenAI Codex CLI call (${role}) and land its output as a file. You may write files only in /tmp and the session dir.
1. Probe: run \`command -v codex\`. Auth is OK if $CODEX_API_KEY or $OPENAI_API_KEY is set, or ~/.codex/auth.json exists.
2. If codex is usable, Write the full prompt below to a temp file (do not hand-escape it), then run from the repo root:
   timeout 660 codex exec -s read-only "$(cat <tmpfile>)" -c model="${CODEX_MODEL}" -c 'model_reasoning_effort="xhigh"' --output-last-message <tmp-out> < /dev/null
   If this codex version rejects --output-last-message, re-run without it and take the final assistant message from stdout (drop banner/timestamp lines). One retry on transient failure. If the error says the model is unknown/unavailable, do NOT retry with a different model.
3. On success: write codex's deliverable (markdown) VERBATIM to ${outFile}, first line exactly \`<!-- author: codex -->\`. Do not rewrite or "improve" its output. Return ok=true, error="", and a ≤80-word summary.
4. If codex is missing, unauthenticated, model-unavailable, or failed twice: do NOT author the deliverable yourself and do NOT write ${outFile}. Return ok=false, summary="", and error = ONE precise actionable line (e.g. "codex not on PATH — npm install -g @openai/codex", "auth expired — run codex login", "model ${CODEX_MODEL} not available on this account — pass codex_model override or wait for GA").

The codex prompt (prefix it with this exact boundary line):
${CODEX_BOUNDARY}

${body}`
}
```

## 3. Policy notes

- **Model pin.** `gpt-5.6-sol` (GPT-5.6 family, Sol = flagship tier)
  announced 2026-06-26; in limited preview at design time, GA expected
  within weeks. It is a single constant per script (`CODEX_MODEL`),
  overridable via the workflow's `args.codex_model` — never hardcoded a
  second time elsewhere in a script.
- **Effort: `xhigh`, not `ultra`.** GPT-5.6 adds `max`/`ultra` reasoning
  tiers, but `ultra` spawns codex-internal sub-agents of its own — redundant
  and token-explosive inside a pipeline that already fans out into many
  agents at the Claude-orchestration layer. Every `codexJob` call is pinned
  to `xhigh`.
- **Hard-stop phases vs. skip-with-flag.** Where codex is a *required*
  input to the phase (plan-draft's `plan:codex` planner, plan-finalize's
  codex-selects-the-plan step) an `ok=false` from `codexJob` is a hard stop:
  the phase itself returns failed/paused and the conductor surfaces the
  error rather than letting the phase silently continue with only Claude's
  half. Where codex is a *per-unit gate* (the build workflow's adversarial
  review of each unit's diff) an `ok=false` does not block the unit: the
  build proceeds with `codex_review: "unavailable: <detail>"` recorded
  loudly in `unit-<id>.json`, and the fleet code-review panel (which runs
  later, over all pushed diffs) still reviews everything — so no diff ships
  without adversarial review, only without codex's specific pass.
- **Skip-with-flag is never ghost-writing.** In both cases above, if codex
  fails, Claude does not write codex's deliverable on its own to make the
  pipeline look green. The distinction is only whether the *phase* halts
  (hard-stop) or the *unit* proceeds with the gap explicitly flagged
  (skip-with-flag) — either way the missing codex output stays missing and
  visible, never quietly backfilled by Claude.

## Verified availability

- **2026-07-09 (UTC):** `timeout 180 codex exec -s read-only "Reply with
  exactly: MODEL_OK" -c model="gpt-5.6-sol" -c
  'model_reasoning_effort="low"' < /dev/null` — model live, first try,
  exit 0, response `MODEL_OK` (codex-cli v0.142.5, account default model is
  gpt-5.5; `gpt-5.6-sol` resolved and answered despite being listed as
  limited preview at design time).
