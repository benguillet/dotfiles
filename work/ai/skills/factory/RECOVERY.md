# /factory — recovery protocol + environment quirks

Lessons from the Paxel account-state run (2026-07-03): five agent deaths, three
app restarts, one zombie resurrection, zero lost work. Follow this and crashes
cost minutes, not hours.

## Why agents die

- **App exit kills local agents.** Background agents/workflows are child
  processes of the Claude Code/Conductor app. Laptop close or app restart kills
  everything in flight ("was running when the previous process exited").
- **Suspension ≠ death.** A "killed" agent can RESUME after laptop reopen and
  collide with the replacement you launched (two writers, one tree). Hence:
  always `TaskStop <task-id>` a presumed-dead agent BEFORE relaunching.
- **The 600s watchdog.** One silent >10min tool call (long `yc` command, big
  test suite) trips "no progress" and the harness kills the agent. Build agents
  must redirect long commands to a log file and poll it.

## Stall → diagnose → fix → relaunch (the ticker watchdog path)

The 15s ticker (SKILL.md "Ticker + watchdog") turns every death into a
visible `⚠⚠ STALL` within ~10 minutes. When one fires:

1. **Confirm it's real.** `TaskGet` the workflow's task. Still `running`,
   and the quiet agent's `agent-*.jsonl` tail shows a long tool call
   mid-flight (test suite, big install)? Not a stall — say so on the next
   tick and keep watching.
2. **Diagnose before touching anything.** Tail the workflow's
   `journal.jsonl` and the quiet/dead `agent-*.jsonl`(s). Classify:

   | evidence in the tails | fix BEFORE relaunching |
   |---|---|
   | `ENOMEM` / OOM during pnpm/bundle/webpack | flush the OrbStack page cache (`/reclaim-memory`), retry |
   | docker: "all predefined address pools have been fully subnetted" | `docker network prune -f` |
   | port in use / stray per-worktree stack | `docker ps`, stop stale `wt-*` stacks |
   | `ConcurrentMigrationError` | another lane is migrating — wait it out, then relaunch |
   | `tsc: command not found` / missing node_modules in a worktree | `pnpm install` in that worktree, or commit from the main tree |
   | workflow returned `{status:'codex-unavailable'}` | codex policy: pause the phase, surface `detail` verbatim — do NOT relaunch |
   | workflow returned `{status:'bad_input'}` | conductor bug — fix the arg shape, relaunch |
   | agent killed by the 600s no-progress watchdog | relaunch; the replacement must redirect long commands to a log file and poll it |
   | nothing conclusive | relaunch once (`resumeFromRunId`) and watch the same spot |

3. **`TaskStop` first** (zombie rule below), clean stale worktrees/stacks,
   then relaunch the phase per the procedure below.
4. **Two identical crashes = stop.** If the relaunch dies the same way, do
   not loop: set the phase `failed`, emit `phase_failed`, and surface the
   evidence to the human.
5. Emit `recovery_performed`, rewrite `state.json`/`STATUS.md`, and
   **restart the ticker** pointed at the NEW workflow's transcript dir.

## Recovery procedure (any death / stall / fresh session)

1. **Read the store, don't assume.** Read `state.json`, tail the last ~20
   lines of `events.jsonl`, and `TaskList` for the run's phase/unit tasks.
   Together these tell you which phase was running (`state.json.phase` plus
   any `phases.<name>.status: "running"` — remember `review_plan`∥`risk` and
   `review_code`∥`verify` can both be running at once) and that phase's
   `workflow_run_id` if it's workflow-backed. `events.jsonl`'s tail is often
   more current than `state.json` if the conductor died mid-phase before its
   next atomic rewrite.
2. **Git-survey every unit**, not just the one you think died. For each entry
   in `state.json.units`: compare local vs `origin/<branch>` SHAs
   (`git rev-parse <branch> origin/<branch>`), and if the unit builds in a
   worktree, `git -C <dir> worktree list` to check whether it's still present
   — a worktree with no corresponding in-progress unit is itself a signal
   (see stale-worktree cleanup below).
3. **Classify each unit** from that survey:
   - **pushed** — `state.json` already says so, or local SHA == origin SHA on
     an MR/PR-bearing branch. Done. Never rebuild.
   - **committed-not-pushed** — local SHA ahead of origin. Push it.
   - **uncommitted** — a worktree with a diff and no commit. Inspect the diff
     before touching anything: a dying agent's last edits may be GOOD work.
     Verify it against the unit's `contract` (from `dag.json`), finish it if
     it's sound, and only discard it if it's actually broken. Never blindly
     restart a unit just because its agent died.
   - **absent** — no worktree, no branch, nothing committed. Clean relaunch.
4. **`TaskStop` every presumed-dead agent BEFORE relaunching anything.**
   Suspension is not death: an agent that looks killed can resume after a
   laptop reopen and race the replacement you just launched — two writers on
   one worktree, corrupting both. This is not hypothetical: the `impl-t12`
   build agent resumed mid-edit after a laptop sleep and collided with its
   own replacement on the same worktree. `TaskStop` first, always — then
   clean up its worktree (below) before relaunching into the same path.
5. **Re-run the CURRENT phase's workflow**, not the whole pipeline — every
   workflow is artifact-idempotent (it probes its own artifacts dir and skips
   finished stages), so a re-run for a stage that's already done returns in
   seconds. The ONE exception is `verify`: it has no probe/skip step and ALWAYS
   re-runs by design — re-verification is exactly what you want after a crash or
   a fix. For `build`, pass only the unfinished `units` and put every
   already-satisfied id in `already_pushed` so those lanes start immediately and
   are never rebuilt. For `fix`, do the OPPOSITE: re-pass the FULL pushed-units
   list (its routing needs every unit's `dir` to map findings onto owning
   branches — `fix` takes no `already_pushed`), and instead trim `findings` to
   those not already actioned in `artifacts/fix/fixes.json` (the workflow also
   probes `fixes.json` and short-circuits when the whole fix phase already
   completed). Same-session interruptions MAY
   also pass `resumeFromRunId` (the phase's stored `workflow_run_id`) to
   replay completed `agent()` calls from the Workflow journal cache — but
   correctness never depends on this: it doesn't survive a fresh session,
   and the git survey + artifact idempotence above is what actually makes
   recovery safe.
6. **Close the loop.** Append a `recovery_performed` event (what died, what
   the survey found, what you relaunched), atomic-rewrite `state.json`
   (tmp file + `mv`, never in place), regenerate `STATUS.md`, `TaskUpdate`
   the affected phase/unit tasks, restart the ticker on the new transcript
   dir, and re-arm the heartbeat (`ScheduleWakeup`).

**Stale worktrees and docker stacks:** dead build agents leave both behind.
`git -C <repo> worktree list` to find worktrees (`<scratch_dir>/wt-<unit
id>`) with no corresponding in-progress unit in `state.json.units` — or
whose unit is `pushed`/`failed`, so the worktree has served its purpose —
and `git worktree remove <path>` each one. Then `docker ps | grep wt-` to
find and stop any per-worktree stack a dead agent started; a leftover stack
squats ports/RAM and can collide with the replacement agent's own stack.

## Concurrency rules that prevented/explained every collision

- **One git writer per working tree.** Parallel lanes = different repos or
  isolated worktrees only. Stacked branches in one repo are sequential.
- Don't run `yc start` (which migrates) while a build agent runs `yc db
  migrate` — advisory-lock crash (`ConcurrentMigrationError`), and a restart
  can SIGKILL the agent's in-flight processes.
- Temp git worktrees have teeth: pre-commit hooks may try to boot a whole dev
  stack from the worktree (port conflicts, daemon errors) and fresh worktrees
  lack node_modules (`tsc: command not found`). Either commit from the main
  tree, or `--no-verify` ONLY after running the hook's checks by a validated
  equivalent route — and say so in the report. Kill leftover per-worktree
  docker stacks afterwards (`docker ps | grep <worktree-name>`).

## YC monorepo quirks (re-verify against CLAUDE.md; true as of 2026-07)

- `yc test local-changes` auto-launches a Playwright **e2e stack** when any
  apply frontend / `.e2e.ts` file changed — an agent rabbit hole. Re-scope to
  direct `yc test <paths>` + `pnpm -F @yc/apply test` and let CI run e2e.
- `yc rbi regen` for **apply** is broken in devbox (apply is DB-less; the
  wrapper needs ActiveRecord). Validated substitute:
  `yc check-all local-changes --no-regen` (exit 0) PLUS
  `yc ssh apply development -c 'bundle exec tapioca dsl --verify'`.
- apply GraphQL codegen: `codegen.yml` points at `127.0.0.1:3001` which isn't
  bound in Conductor stacks — point a transient codegen config at the
  workspace's proxied dev URL (e.g. `http://apply.<ws>.yclocal.com/graphql`,
  after the backend change is live/hot-reloaded), then delete it.
- `yc start` can fail on known bad dev rows (e.g. jobs_messages NULL
  company_id → delete those rows in ycinternal_dev and retry).
- Local login when the SSO/account app isn't running (it's served by
  bookface): mint a session directly — insert an `sso_sessions` row for the
  dev user via ycinternal rails runner, set cookie `_sso.key.dev=<key>` on
  `.<ws>.yclocal.com`. Delete the row to revoke.
- Stray stacks accumulate (e2e stacks, per-worktree stacks) and squat
  ports/RAM — `docker ps`, remove anything not belonging to the live
  workspace stack.

## Shell traps (macOS + this Bash tool)

- BSD `mktemp` ignores a suffix after `XXXXXX` (creates the literal name) and
  noclobber then fails the `>` redirect — Xs go LAST (`mktemp /t/x.XXXXXX`),
  and use `>|` or `rm -f` when overwriting possibly-existing files.
- Never pipe `yc` commands through `head/tail/grep` (blocked by hook) —
  redirect to a file.
