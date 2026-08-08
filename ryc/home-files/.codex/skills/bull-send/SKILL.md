---
name: bull-send
description: Create MR (or use existing), monitor CI/CD pipeline + reviewer comments, auto-fix issues, launch the local stack, and surface the MR link plus clickable local test links after every monitoring round. Exactly like full-send EXCEPT it NEVER auto-merges — you review/test locally and merge yourself.
---

# Bull Send

Create a GitLab MR (or use an existing one), monitor the CI/CD pipeline and reviewer comments, and auto-fix issues as they arise — same as `/full-send`. The differences:

- **It NEVER auto-merges.** When everything is green it tells you the MR is ready and stops. Merging is your call.
- **It launches the local dev stack** so you can manually test the change.
- **It surfaces links** — the MR URL the moment the MR is open, and the MR URL + clickable local test links **after every babysit (monitoring) round**.

## User's Request

$ARGUMENTS

## Constants

- **Poll interval**: 15 seconds
- **Poll command timeout**: 540 seconds (9 minutes — must stay under the 10-minute Bash tool cap)
- **Bash tool timeout**: 600000 milliseconds (always set this on wait-for-action-items calls)
- **Overall timeout**: 1 hour (3600 seconds)
- **Max same-failure recurrences**: 2 (stop if the same category fails twice after being "fixed")
- **Max total fix pushes**: 6 (safety cap)

---

## Reusable: Surface Links

Whenever a step says **"surface links"**, print this compact block (skip the local part gracefully when the stack isn't up yet or `yc` is unavailable):

```
🔗 MR: <MR_URL>   (status: <pipeline status> · <mergeable? yes/no>)
🧪 Test locally:
   - <clickable link to each affected page, built per the rules below>
```

Building the local test links:

1. Get the base URL(s) for the running stack: `yc stacks url`. **Never hardcode the host/port** — it varies by stack/workspace.
2. For each page the diff affects, build a clickable link to that **specific** page, using **real record IDs** pulled from the data the change touches (the app, interview, company, user, etc.). If you don't have a concrete ID, query for one (Rails console via `/rc`, or the DB) rather than emitting a `:id` placeholder.
3. If the change is **not** user-facing (pure backend/refactor/migration), say so and give the base URL plus the single most relevant page to spot-check instead of inventing links.

---

## Reusable: Launch the Local Stack

Whenever a step says **"launch the local stack"**:

1. Detect which app(s) the diff touches from the top-level directories of the changed files: `bookface`, `ycinternal`, `apply` (a `shared/` only change usually surfaces in `ycinternal`).
2. Start them: `yc start <app1,app2>`. This can take a few minutes — run it (you may run it in the background so monitoring can proceed in parallel) and do **NOT** pipe it through `tail`/`head`/`grep`.
3. Once up, get the URLs with `yc stacks url`.
4. If the `yc` CLI is unavailable (e.g. you're not in the YC monorepo), skip launching and note that local test links aren't available here.

---

## Phase 1: Ensure MR Exists

### 1. Check for Existing MR

```bash
# git:
branch=$(git rev-parse --abbrev-ref HEAD)
# jj:
branch=$(jj log -r @ -T 'local_bookmarks.map(|b| b.name()).join(",")' --no-graph 2>/dev/null | head -1)

echo "Branch: $branch"
glab mr list --source-branch "$branch" -F json | jq -r '.[0].iid // empty'
```

If an MR IID is returned, skip to Phase 2 — store the IID and proceed to step 6 (launch stack + surface links), then step 7.

If no MR exists, continue to step 2.

### 2. Ensure Feature Branch

If on master, create a feature branch:

1. Get username: `glab config get user`
2. Generate a short, descriptive branch name with the username as prefix
3. `git checkout -b <branch-name>` (jj: `jj bookmark create <branch-name>`)
4. Tell the user: "You were on master, so I've created branch: `<branch-name>`"

If already on a feature branch, continue.

### 3. Handle Uncommitted Changes

```bash
# git:
git status --porcelain
# jj:
jj st
```

Also check specifically for uncommitted plan files:

```bash
# git:
git status --porcelain .coding-agent-plans/
# jj:
jj st .coding-agent-plans/
```

If there are uncommitted changes, ask: **"You have uncommitted changes [including a plan file in `.coding-agent-plans/` if applicable]. Should I commit them before creating the MR?"**

If yes, run `/commit`. If no, continue.

### 4. Ask About Conversation History

Ask: **"Would you like me to attach the conversation history to the MR?"**

Options:
- **"Yes, just post it"** — extract and post directly
- **"Yes, with preview"** — show for review first
- **"No"** — skip

Store their preference for use after MR creation in step 5d.

### 5. Gather Context and Generate MR

#### 5a. Get the diff

```bash
# git:
git diff $(git merge-base master HEAD) --stat
git diff $(git merge-base master HEAD)
# jj:
jj diff --from trunk() --stat
jj diff --from trunk()
```

#### 5b. Determine Team

> **Note:** In the YC monorepo the `/mr` and `/tag-reviewers` skills are **repo-local** — they live in the project's `.claude/skills/` directory (`.claude/skills/mr/SKILL.md` and `.claude/skills/tag-reviewers/SKILL.md`), **not** in global `~/.claude/skills/`. Read them from the repo root of the current workspace. Don't look for them under `~/.claude`.

Use the same team detection logic as the `/mr` skill (see `.claude/skills/mr/SKILL.md` step 3 for the full priority order, team alias mappings, member lists, git blame rules, and subject matter heuristics). The priority order is:

1. User specified a team argument (e.g., `/bull-send infra`)
2. Current glab user is on a team (check `glab config get user` against the member list)
3. Git blame analysis of changed files
4. Subject matter heuristics based on files/directories touched

#### 5c. Generate title and description

Create a concise, lowercase title. Build the description. **Every section must have real content** — never ship empty `### Background` / `### Changes` / `### Test Plan` headers.

```
### Background

[The *why*. What problem this solves, pulled from conversation context. 1-4
sentences. Do NOT describe the diff here.]

### Changes

[The *what*. Concrete list of what this MR does, written from the diff. Bullets
when there are multiple distinct changes. Be specific.]

### Test Plan

[How was / will this be tested? If genuinely no useful way to test (e.g. docs,
prompt edits), just write `untested` — but never leave the section blank.]

### Claude's TL;DR

[Super direct, informal summary. 1-3 sentences. No fluff.]
```

**Background**: the *why*, from conversation context — not a restatement of the diff.
**Changes**: the *what*, mirroring the diff.
**Test Plan**: never blank; `untested` is a valid value.
**TL;DR**: short, clear sentences, 1-3 max.

#### 5d. Create the MR

Push the branch and create the MR directly from the CLI — no browser interaction required:

```bash
# git:
git push -u origin <branch>
# jj:
jj git push --bookmark <branch>
```

Get the current glab username (the author):

```bash
glab config get user
```

Then create the MR. `/bull-send` always assigns reviewers (unlike `/mr`, which leaves them off by default) AND assigns the MR to the author. For the reviewer member lists / team-to-reviewer mappings, use the repo-local `/tag-reviewers` skill (`.claude/skills/tag-reviewers/SKILL.md`) as the source of truth:

```bash
glab mr create \
  --title "<title>" \
  --description "<description>" \
  --target-branch master \
  --assignee <AUTHOR_USERNAME> \
  --reviewer <comma-separated team members> \
  --squash-before-merge \
  --remove-source-branch \
  --yes
```

The `--yes` flag skips the confirmation prompt so it creates immediately. Parse the MR IID and the MR URL from the output.

**If user opted in to conversation history**, post it after MR creation:

1. Extract human messages from JSONL transcript files on disk (see `/mr` skill Step 8 for the full Python extraction script with system message filtering)
2. Write the comment to `/tmp/mr-conversation-history.md`, then post via `glab mr note <MR_IID> -m "$(cat /tmp/mr-conversation-history.md)"`
3. Post messages VERBATIM — never summarize or paraphrase. Long messages inside `<details>` collapse tags are fine.

### 6. Launch the Stack and Surface the MR Link

As soon as the MR is open:

1. Tell the user the MR is up and **surface links** (at this point the MR URL plus, once the stack is up, local test links).
2. **Launch the local stack** (you may start it in the background so it warms up while CI runs).

---

## Phase 2: Monitor, Fix, and Surface (no auto-merge)

### 7. Wait for Action Items

```bash
yc gitlab wait-for-action-items --timeout 540 --interval 15 --wait-for any
```

**IMPORTANT: Set the Bash tool timeout to 600000 milliseconds (10 minutes) on this call.**

Store key info from the output:
- `MR_IID`, `MR_URL`, `TARGET_BRANCH`
- Pipeline status
- Failed job log file paths
- Unresolved comment details

#### Handling timeout and errors

- **If the command exits because the 540-second timeout was reached** (nothing actionable yet): This is normal — the poll window is intentionally short to stay within tool limits. Re-run the same command immediately to continue waiting. Keep re-running until action items appear or 1 hour total has elapsed since you started watching.

- **If the command fails with a network error, connection refused, SSL error, or other unexpected error**: This likely means the laptop slept and network connections died. This is recoverable — wait 5 seconds, then re-run the command. The command will establish fresh connections.

- **If 1 hour total has elapsed** across all retries:
```bash
terminal-notifier -title "Bull Send Timeout" -message "Pipeline still running after 1 hour. Check manually." -open "MR_URL"
```
Stop monitoring.

**If output contains `BRANCH_CHANGED:`**: Stop and show the message to the user. Wait for them to switch back, then process the action items.

**Pipeline statuses:**
- `success` with no unresolved comments → go to step 11 (ready to merge — surface links, do NOT merge)
- `success` with unresolved comments → go to step 8b (triage comments)
- `failed` → go to step 8 (triage)
- `canceled`, `skipped` → tell user the pipeline was externally canceled/skipped and stop

### 8. Evaluate and Triage

Track what category of failure you fix in each attempt (for the smarter fix attempt logic in step 10). Categorize everything returned:

#### 8a. Pipeline Failures

Read each failed job's log file. Categorize:

| Category | Detection | Auto-fixable? | Action |
|----------|-----------|---------------|--------|
| **Merge conflicts** | "CONFLICT", "Merge conflict", "needs merge", "cannot merge", "fix conflicts" | Sometimes | Rebase onto target branch |
| **RuboCop/Lint** | "rubocop", "offense", "Style/" | Usually | `rubocop -a` + manual fixes |
| **TypeScript errors** | "error TS", "Type error" | Usually | Read files, fix types |
| **Spec failures** | "Failure:", "expected", "FAILED" | Sometimes (obvious only) | Fix obvious issues |
| **Unrecoverable** | "out of disk space", "runner offline", "project archived", "quota exceeded" | No | Alert user |
| **Transient** | "timed out", "stuck or timeout", "runner system failure", "docker", "network error", "connection refused", "500", "502", "503" | Retry | `glab ci retry <pipeline_id>`, then re-poll |

**For transient failures**: Retry the pipeline before giving up:
```bash
glab ci retry <pipeline_id>
```
Then go back to step 7 to poll for the retried pipeline. If the same transient failure recurs after retry, notify the user and stop.

#### 8b. Comments (Bugbot / Reviewers)

For each unresolved comment, independently analyze:

1. **Is the concern valid?** Read the file and surrounding context
2. **Is the fix obvious?** Can you implement without design input?
3. **Is this a style nit or a real issue?**

Classify each:

| Verdict | When | Action |
|---------|------|--------|
| **Auto-fix** | Valid feedback with an obvious fix | Fix silently |
| **Alert user** | Valid but needs design input, or you disagree | Show comment + analysis, ask user |
| **Decline** | Clearly wrong or not applicable | Draft response, get user approval |

**Weight human feedback more heavily than bot feedback.**

### 9. Apply Fixes

Apply fixes in this order:

#### Merge conflicts (first):
```bash
# git:
git fetch origin <TARGET_BRANCH>
git rebase origin/<TARGET_BRANCH>
# jj:
jj git fetch
jj rebase -d <TARGET_BRANCH>@origin
```
If complex conflicts, abort (`git rebase --abort`, jj: `jj undo`) and alert user. **Rebase only, never merge.**

#### Lint/type errors:
```bash
yc check-all local-changes
```
For RuboCop:
```bash
yc ssh ycinternal development -c 'bundle exec rubocop -a'
yc ssh bookface development -c 'bundle exec rubocop -a'
```
For TypeScript: read files, fix types. Verify with `yc check-all local-changes`.

#### Spec failures (obvious only):
```bash
yc test local-changes
```
Only fix if clearly caused by your changes. If complex, alert user.

#### Obvious comment feedback:
Apply fixes directly for straightforward corrections (null guards, missing types, off-by-one, etc.).

### 10. Commit, Push, Surface, and Loop

If any fixes were applied:

```bash
yc gitlab auto-commit -m "fix: address pipeline failures and review feedback

Fixes applied:
- [List each fix]

Auto-fixed by Claude bull-send"
```

```bash
# git:
git push
# jj:
jj git push
```

Post an MR note:
```bash
yc gitlab auto-note <MR_IID> -m "### Auto-Fix Applied

- [List each fix]

*Auto-fixed by Claude bull-send*"
```

#### Surface links after this babysit run

Whether or not you applied fixes this round, **surface links** now (MR URL + local test links) so the user always has them after every monitoring round.

#### Wait for remaining action items

If you got early results from `--wait-for any` AND you did **not** make any code changes, wait for all sources before looping:

```bash
yc gitlab wait-for-action-items --timeout 540 --interval 15 --wait-for all
```

**IMPORTANT: Set the Bash tool timeout to 600000 milliseconds on this call.** Apply the same timeout/error retry logic from step 7.

Address any new action items from steps 8-9.

**If you DID make code changes**, skip the wait — pushing triggers a new pipeline so current results are stale.

#### Loop back

Go back to step 7 to watch the new pipeline.

**Fix attempt tracking** (smarter than a simple counter):

Keep a running log of what category of failure was fixed in each push (e.g., "push 1: rubocop", "push 2: typecheck", "push 3: spec").

**Stop conditions:**
- The **same failure category** has recurred 2 times after being "fixed" (the fix isn't working). Notify user and stop.
- **6 total fix pushes** reached (safety cap). Notify user and stop.
- All remaining issues are non-auto-fixable and user has been alerted.

**Do NOT stop** just because you've pushed N fixes. If each push fixes a different problem and the pipeline surfaces a new issue, keep going.

### 11. Ready to Merge (DO NOT auto-merge)

**This is where `/bull-send` deliberately differs from `/full-send`: it never merges.**

When the pipeline passes AND there are no unresolved comments, check whether the MR is genuinely mergeable (informational only — for you, not to act on):

```bash
glab mr view <MR_IID> -F json | jq '{
  pipeline_status: .head_pipeline.status,
  merge_status: .detailed_merge_status,
  has_conflicts: .has_conflicts,
  blocking_discussions_resolved: .blocking_discussions_resolved
}'
```

Then:

1. Make sure the local stack is up (**launch the local stack** if it isn't yet).
2. **Surface links** — the MR URL and clickable local test links for the affected pages.
3. Report readiness honestly:
   - If `merge_status` is `"mergeable"`, `has_conflicts` is `false`, `blocking_discussions_resolved` is `true`, and `pipeline_status` is `"success"` → tell the user: **"✅ MR !<MR_IID> is green and ready to merge. I did NOT merge it — test it locally with the links above, then merge it yourself when you're happy."**
   - Otherwise → tell the user it's green on CI but **not** mergeable yet and why (e.g., draft, missing approvals, blocked by policy, conflicts).
4. Send a desktop notification, then **stop** (do not merge, do not watch any deploy):

```bash
terminal-notifier -title "Bull Send Ready" -message "MR !<MR_IID> is green — ready for you to test & merge." -open "<MR_URL>"
```

### 12. Alert User on Non-Obvious Issues

For anything that needs human judgment, present it clearly:

```
## MR !<MR_IID> needs your input

### Comment feedback (needs decision):
1. **[file.rb:42]** Reviewer suggests X.
   **My take**: [Your analysis]
   **Options**: Fix it / Decline / Skip

### Pipeline failure (can't auto-fix):
- **infrastructure**: Redis timeout — likely transient. Retry?

### Merge conflict (complex):
- Conflict in `app/models/user.rb` — both branches modified the same method.
```

Use `AskUserQuestion` to let them decide. Apply their decisions, then loop back to step 10 to commit/push.

---

## Final Summary

When monitoring ends (green & ready, or stopped on a stop condition):

```
## MR !<MR_IID> — Bull Send Status

**MR**: <MR_URL>
**MR Pipeline**: Passed / Failed / <status>
**Mergeable**: yes — ready for you to merge / no — <reason>
**Local stack**: <app(s)> up at <base URL> (or: not available)
**Test these**:
- <clickable local link 1>
- <clickable local link 2>
**Monitoring rounds**: N

### Auto-fixed
- [rubocop] Fixed Style/StringLiterals in 2 files
- [bugbot] Added nil guard on `user.company` in serializer
- [merge conflict] Rebased onto latest master

### Alerted (user decided)
- [bugbot] Declined service extraction suggestion — responded on MR

> Not merged — bull-send never merges. Review and test locally, then merge when you're happy.
```

---

## Important Notes

- **Never merges.** `/bull-send` stops at "ready to merge" — pressing the merge button is always your call.
- **Always surface links after every babysit round** — the MR URL and clickable local test links — so you can manually test at any point.
- **Build local links against the running dev server** with `yc stacks url`; never hardcode the host/port, and use **real record IDs**, not `:id` placeholders.
- **Never post comment responses without explicit user approval** — always show the draft first
- **Auto-fix only when the fix is obvious** — when in doubt, alert the user
- **Weight human feedback more heavily than bot feedback** — a teammate took time to write it
- **Don't blindly accept all feedback** — good code review is a dialogue
- **Prefer rebase over merge** for conflict resolution
- **Verify fixes locally** before pushing (`yc check-all local-changes`, `yc test local-changes`)
- **Never amend commits** — always create new commits
- **Handle stale feedback carefully** — if failures or comments refer to code that has changed locally, don't revert to old code. Exercise judgment about whether the underlying concern can be incorporated into the current code
