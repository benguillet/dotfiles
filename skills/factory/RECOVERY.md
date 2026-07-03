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

## Recovery procedure (any death / stall / fresh session)

1. **Survey, don't assume.** For every lane: `git status --short`,
   `git branch --show-current`, and local-vs-origin SHA per factory branch
   (`git rev-parse <b> origin/<b>`). Read `.context/factory-status.md` and
   `TaskList` to see what was in flight.
2. **Classify partial work**: pushed (done — never rebuild), committed-not-
   pushed (push it), uncommitted (inspect the diff — a dying agent's last edits
   may be GOOD work worth landing: verify against its intent, test, commit on
   the owning branch), or absent (clean relaunch).
3. **TaskStop the old agent id**, then relaunch ONE agent with a
   "finisher" prompt: "the implementation may be partially present — verify the
   inherited diff, repair, run the gate, ship" (never "rewrite wholesale").
4. Workflows: relaunch with `resumeFromRunId` — the journal replays completed
   `agent()` calls from cache.
5. Update the scoreboard + task list; re-arm the heartbeat wakeup.

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
