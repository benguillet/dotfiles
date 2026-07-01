---
name: sprint-demos
description: |
  Build Ben's sprint-planning demo package: collect everything he shipped since the last
  sprint planning (GitLab MRs in yc-software/code, yc-software/data/etl, and
  yc-software/infrastructure/infra + GitHub PRs in yc-software/paxel, merged AND open),
  group into demoable features, determine per-feature whether it's live in prod,
  produce clickable prod links (or start the right Conductor workspace's local stack, seed
  data, and give local links), take screenshots, and publish a claude.ai artifact demo deck.
  TRIGGER when the user says "sprint demos", "prep sprint planning", "what did I ship",
  "what did I ship this week/last week", "demo prep", "build my demo deck", or any variation
  of preparing demos for sprint planning. Sprint planning is every Wednesday 10:30–11:30am
  Pacific; this normally runs Tuesday evening or Wednesday morning right before.
---

# Sprint Demos

Assemble a demo-ready package of everything Ben shipped since the end of the last sprint
planning: grouped features, prod-vs-local status, one-click demo links, screenshots, and a
published claude.ai artifact deck he can present from.

Work autonomously. Parallelize aggressively (stack startup is slow — kick it off early in
the background and keep working). Degrade gracefully: a feature you can't fully wire up for
demo still goes in the report with whatever links/screenshots you could get and a note on
what's missing. Never block the whole run on one broken piece.

## User's Request

$ARGUMENTS

## Options

Parse `$ARGUMENTS` before starting:

- A time expression ("2 weeks", "since June 15", "last sprint") overrides the default
  one-week window.
- `no-artifact` — skip the claude.ai artifact; just deliver the report + local HTML deck.
- `no-local` — don't start any local stacks; unshipped features get MR links + screenshots
  from the MR only.
- Anything naming a specific feature/branch/MR — scope the run to just that.

## Environment gotchas (read first, they will bite)

- Every Bash call in Conductor workspaces prints 2 `direnv:` lines on stderr — ignore them.
- The Bash tool has noclobber ON: `>` fails on existing files. `rm -f` the target first
  (or use the Write tool).
- **NEVER pipe `yc` commands through `| head`, `| tail`, or `| grep`** — a hook blocks it.
  Redirect to a file and inspect that.
- This shell exports `GH_HOST=gitlab.com` and `gh`'s gitlab token is stale — bare `gh`
  commands hit the wrong host and fail (401/410 depending on endpoint). **Always prefix
  `GH_HOST=github.com`.**
- GitLab `environments` / `deployments` APIs return 403 with the current glab token — only
  pipelines/bridges/jobs endpoints work.
- Don't name a zsh variable `status` (read-only in zsh).
- Prod is **read-only** in this skill. Queries for demo record IDs only. No writes, ever.

## Repos covered

| Repo | Platform | Local checkout | Default branch | Prod signal |
|---|---|---|---|---|
| `yc-software/code` (monorepo) | GitLab | the current Conductor workspace (or `/Users/ben/Work/yc/code`) | `master` | per-app deployed SHA + ancestry (step 4) |
| `yc-software/data/etl` | GitLab | `/Users/ben/Work/yc/etl` | `master` | master pipeline on the merge commit (step 4) |
| `yc-software/infrastructure/infra` | GitLab | `/Users/ben/Work/yc/infra` | `master` | master pipeline on the merge commit = terraform applied (step 4) |
| `yc-software/paxel` | GitHub | `/Users/ben/Work/yc/paxel` | `main` | GitHub production Deployment + ancestry (step 4) |

Note the GitLab subgroup paths — `yc-software/etl` and `yc-software/infra` only resolve
via redirect. Run `glab api "projects/:fullpath/..."` from inside each local checkout and
the path resolves itself. Run all git ancestry tests / fetches inside the matching
checkout too.

## Process

### 1. Compute the sprint window

Sprint planning: Wednesdays 10:30–11:30am Pacific. The window is from the **end of the most
recent planning (Wednesday 11:30am PT)** to now:

```bash
now_epoch=$(date +%s)
wed_local=$(TZ=America/Los_Angeles date -v-wed -v11H -v30M -v0S '+%Y-%m-%dT%H:%M:%S%z')
wed_epoch=$(TZ=America/Los_Angeles date -j -f '%Y-%m-%dT%H:%M:%S%z' "$wed_local" +%s)
if [ "$wed_epoch" -gt "$now_epoch" ]; then   # it's Wed before 11:30 → previous Wednesday
  wed_local=$(TZ=America/Los_Angeles date -v-wed -v-7d -v11H -v30M -v0S '+%Y-%m-%dT%H:%M:%S%z')
  wed_epoch=$(TZ=America/Los_Angeles date -j -f '%Y-%m-%dT%H:%M:%S%z' "$wed_local" +%s)
fi
SINCE_UTC=$(date -u -r "$wed_epoch" '+%Y-%m-%dT%H:%M:%SZ')
SINCE_DATE=$(date -u -r "$wed_epoch" '+%Y-%m-%d')
```

Edge case: if this runs Wednesday *afternoon* (after 11:30), the window starts **today**
11:30 and will be nearly empty — that usually means Ben wants next week's prep started or
is testing. Say so, and offer the previous full week (`-v-7d`) instead.

Do NOT trust `merged_after`/`created_after` semantics blindly — see the gotchas inline
below. All GitLab/GitHub API timestamps are UTC `Z`-suffixed; compare as strings.

### 2. Collect shipped work (both platforms, in parallel)

**GitLab (code, etl, infra)** — same query, run once from inside EACH local checkout
(`:fullpath` resolves from the cwd's remote; see the Repos table):

```bash
GL_USER=$(glab api user | jq -r .username)   # → benguillet
for repo_dir in <monorepo-checkout> /Users/ben/Work/yc/etl /Users/ben/Work/yc/infra; do
  (cd "$repo_dir" && glab api "projects/:fullpath/merge_requests?author_username=${GL_USER}&updated_after=${SINCE_UTC}&state=all&per_page=100")
done
```

If `glab api user` errors or `GL_USER` comes back empty, stop and tell Ben to
`glab auth login` — nothing downstream works without it.

- **GOTCHA: `merged_after` is silently ignored by this endpoint.** Filter server-side with
  `updated_after` (merging bumps `updated_at`), then client-side:
  keep merged MRs with `merged_at >= SINCE_UTC`, and open MRs (state `opened`) that had
  activity in the window. Closed-unmerged MRs: list in one line as "abandoned/superseded",
  never demoed.
- Useful fields per MR: `iid`, `title`, `description`, `state`, `merged_at`,
  `merge_commit_sha` (non-null only when merged — this is the commit that landed on
  master), `web_url`, `source_branch`, `draft`, `labels`.
- If `X-Total-Pages` > 1 (check with `glab api --include`), follow `X-Next-Page`.

Changed files per MR (to know which app it touches):

```bash
glab api "projects/:fullpath/merge_requests/<IID>/diffs?per_page=100" | jq -r '.[].new_path'
```

App = first path segment: `bookface`, `ycinternal`, `apply` → that app; `shared/` → treat
as touching all three (check all three in step 4); `tools/`, `deploy/`, `docs/`, `cli/`,
`.claude/` → not user-facing (no prod link needed; still reportable). This rule is
monorepo-only — an etl or infra MR's "app" is just its repo.

**GitHub (paxel, plus any other repo Ben touched)** — deliberately unscoped so work
outside paxel is caught too:

```bash
GH_HOST=github.com gh search prs --author=@me --updated=">=${SINCE_DATE}" \
  --json title,url,state,repository,closedAt,isDraft,updatedAt,number --limit 100
```

`state` is `"merged"`/`"open"`/`"closed"` — keep merged with `closedAt >= SINCE_UTC`, and
open ones with `updatedAt >= SINCE_UTC` (`--updated` is only date-granular; filter
client-side against the full timestamp). For merge commit and changed files on a specific
PR:

```bash
GH_HOST=github.com gh pr view <N> --repo yc-software/paxel --json mergeCommit,files,mergedAt,baseRefName
```

### 3. Group into demoable features

This is a judgment step, not a script. Cluster MRs/PRs into **2–6 named demo features**:

- Same Linear ticket (`IO-1234` in title/description/branch), same branch-name stem, same
  subsystem, or an obvious product narrative (e.g. five Paxel-scores MRs = one feature
  "Paxel builder scores on YC applications"). Cross-platform clusters are common — a paxel
  PR and a monorepo MR often serve one feature; group them together.
- Each feature gets: a demo title (what Ben would say out loud), a 1–2 sentence demo
  narrative ("the story"), its constituent MRs/PRs, and the user-visible entry point
  (which page/flow shows it).
- Everything that isn't demo-worthy (typo fixes, flaky-test fixes, refactors, bumps) goes
  in a single "Also shipped" bucket — one line each, no demo work.
- Purely invisible-but-important work (migrations, infra) can still be a "talk track" item:
  mark it `no-ui` and give it a one-liner instead of links/screenshots.

### 4. Determine prod status per feature

Get the currently-deployed master SHA per monorepo app (**ground truth = the REVISION baked
into the running container / the deploy marker**, never pipeline top-level status):

```bash
D_BOOKFACE=$(curl -s https://bookface.ycombinator.com/healthcheck | grep -oE '[0-9a-f]{40}')
D_APPLY=$(curl -s https://apply.ycombinator.com/healthcheck | grep -oE '[0-9a-f]{40}')
# ycinternal's healthcheck is behind employee auth — use the deploy S3 marker instead:
rm -f /tmp/sprint-demos/s3m.json && mkdir -p /tmp/sprint-demos
yc aws s3api list-objects-v2 --bucket ycinternal-static-production-7a3b7d --prefix deployed/ --output json > /tmp/sprint-demos/s3m.json
D_YCINTERNAL=$(jq -r '.Contents | sort_by(.LastModified) | .[-1].Key | sub("deployed/";"")' /tmp/sprint-demos/s3m.json)
```

Then, per merged MR (`M = merge_commit_sha`), for **each app the MR touches**:

```bash
git fetch origin master --quiet
git merge-base --is-ancestor "$M" "$D_APP" && echo LIVE || echo NOT-LIVE
```

Feature status rollup — judged on the **user-visible surface**, not plumbing:
- ✅ **Live in prod** — every constituent MR merged AND ancestor of the deployed SHA for
  every app it touches (and its paxel PRs, if any, are deployed too).
- 🟡 **Partially live** — some user-visible parts are live, others still open or
  merged-but-not-deployed.
- 🔴 **Not in prod** — nothing *user-visible* is deployed yet (open MRs, or merged minutes
  ago and still rolling out). Merged backend plumbing alone keeps a feature 🔴 — mention
  the live plumbing in the narrative instead.

Fallback if a healthcheck/marker is unreachable — walk master pipelines and find the newest
one whose app child pipeline has a successful deploy job (job-level status, never
pipeline-level; the jobs API lists retries so accept any success):

```bash
APP=bookface   # or ycinternal / apply
for pid_sha in $(glab api "projects/:fullpath/pipelines?ref=master&per_page=15" | jq -r '.[] | "\(.id):\(.sha)"'); do
  pid=${pid_sha%%:*}; psha=${pid_sha##*:}
  gen=$(glab api "projects/:fullpath/pipelines/$pid/bridges?per_page=20" | jq -r '.[] | select(.name=="Generated Pipelines (Master)") | .downstream_pipeline.id // empty')
  [ -z "$gen" ] && continue
  apppipe=$(glab api "projects/:fullpath/pipelines/$gen/bridges?per_page=50" | jq -r --arg app "$APP" '.[] | select(.name==$app) | .downstream_pipeline.id // empty')
  [ -z "$apppipe" ] && continue
  dstat=$(glab api "projects/:fullpath/pipelines/$apppipe/jobs?per_page=100" | jq -r '[.[] | select(.name=="deploy_production" or .name=="deploy_production_manual") | .status] | if any(.=="success") then "success" else .[0] // "none" end')
  if [ "$dstat" = "success" ]; then echo "DEPLOYED_SHA=$psha"; break; fi
done
```

(Note: an app's deploy only runs on master pipelines that touched that app's files — which
is exactly why you test *ancestry against the deployed SHA* rather than asking "did this
MR's pipeline deploy".)

**etl and infra** (no user-facing deploy target — the merge commit's own master pipeline
is the ship signal): from inside the repo's local checkout,

```bash
glab api "projects/:fullpath/pipelines?ref=master&sha=${M}&per_page=5" | jq -r '.[0].status // "none"'
```

`success` → shipped (for infra that means terraform applied); `running`/`pending` → still
rolling out; `failed`/`none` → merged but NOT applied — say so explicitly, with the
pipeline `web_url`, since a failed infra apply is exactly the kind of thing Ben wants to
know before standup. Fallback: ancestor-of-newest-green-master-pipeline, as for the
monorepo. These MRs usually aren't browser-demoable — demo links are the MR itself, the
affected dashboard (Amplitude/Chartio for etl), or `/tf-plan-summary` output for infra;
never force a local stack for them.

**Paxel** (default branch is `main`, NOT master): paxel deploys via a `Deploy` GitHub
Actions workflow on `main` that creates a GitHub Deployment (environment `production`,
"Production rollout via GitHub Actions"). The deployed paxel SHA = `sha` of the newest
production deployment whose latest status is `success`:

```bash
GH_HOST=github.com gh api "repos/yc-software/paxel/deployments?environment=production&per_page=5" \
  | jq -r '.[0] | "\(.id) \(.sha)"'
GH_HOST=github.com gh api "repos/yc-software/paxel/deployments/<id>/statuses?per_page=1" | jq -r '.[0].state'
```

Then the same ancestry test in `/Users/ben/Work/yc/paxel` (fetch `origin main` first)
against each PR's `mergeCommit`. Corroborate with
`GH_HOST=github.com gh run list --repo yc-software/paxel --branch main --limit 10 --json headSha,conclusion,workflowName`.
If anything is ambiguous, mark the PR "merged — prod status unverified" rather than
guessing.

### 5. Live features → clickable prod links

For each ✅ (and the live parts of 🟡) feature, produce direct links to where the feature is
visible, **with real record IDs** — never `:id` placeholders. Find good demo records with
read-only prod queries via the `/rc` skill (invoke the skill first — its `rc-run` helper
is not on PATH) or `ycli tool select-query` — pick records that show the feature at its
best (recent, fully populated, not test data).

Prod hosts (from `YC::Hostnames::SERVICES`):

| App | Host | Common record paths |
|---|---|---|
| ycinternal | `https://internal.ycinside.com` | `/companies/<id>`, `/users/<id>`, `/apps/<id>` (+ `/apps/<id>/hunting` review card), `/agents/<id>`, `/batches/<name>`, `/meetups/<id>` |
| bookface | `https://bookface.ycombinator.com` | `/posts/<id>`, `/user/<id>` (singular!), `/company/<bf_company_id>` (singular! **bf_companies.id, not companies.id** — use `company.bf_company.id`) |
| apply | `https://apply.ycombinator.com` | `/apps/<uuid>` (founder-facing; staff view is internal `/apps/<id>/hunting`) |
| others | `account.ycombinator.com`, `events.…`, `deals.…`, `investors.…`, `www.workatastartup.com`, `www.startupschool.org`, `finance.ycinside.com` | as needed |

All prod apps SSO-bounce through `account.ycombinator.com` and return to the exact deep
link, so links are safe to hand out (internal.ycinside.com is staff-only — fine for Ben).

### 6. Unshipped features → local demo on the right workspace stack

For each 🔴 feature (and the unshipped parts of 🟡), unless `no-local`. This applies to
**monorepo** features; etl/infra get MR/dashboard links (step 4), and an unshipped paxel
feature can be demoed from `/Users/ben/Work/yc/paxel` (check out the PR branch, run its
dev server per that repo's README) only if it's the centerpiece of the week — otherwise
PR link + screenshots from the PR.

1. **Find the workspace** holding the MR's `source_branch`:
   ```bash
   for d in /Users/ben/conductor/workspaces/code/*/; do w=${d%/}; [ -L "$w" ] && continue; b=$(git -C "$w" rev-parse --abbrev-ref HEAD 2>/dev/null) && echo "$b -> $w"; done
   ```
   (Symlinks in that dir are Conductor's friendly-name aliases — skip them; the real dirs
   are city names. If no workspace has the branch, don't hijack another workspace's
   checkout — report it and fall back to the MR link + MR screenshots.)
2. **Check whether its stack is already running**: `yc stacks list` and match on the
   `Directory:` field, not the stack name — stack names usually equal the workspace dir
   basename but not always (the registry has counterexamples, including stacks registered
   under symlink-alias paths). Or `docker ps --format '{{.Names}}'` and look for
   `yc-<stack>-…` containers once you know the stack name.
3. **Start it (background, early!)**: `cd <workspace> && yc start <app>` for just the
   app(s) the feature needs (`ycinternal`, `bookface`, `apply`; plain `yc start` = all
   three). Startup takes several minutes — launch it as a background task the moment you
   know you'll need it (i.e. right after step 4) and keep doing steps 5/7 meanwhile. If
   multiple features need different workspaces, prefer starting stacks sequentially and
   flag memory pressure rather than launching four stacks blind.
4. **Get the base URLs**: `yc stacks urls` in the workspace →
   `http://<label>.<stack>.yclocal.com/` per app (ycinternal's label is `internal`).
5. **Log in**: append `?cu=benguillet` to any local URL (dev-only `current_user` override;
   Ben = hnid `benguillet`, admin). This needs no cookies, so it works from any browser.
6. **Verify + seed**: open the feature's actual page. If it's empty or broken from missing
   data, seed it — targeted inserts via `/rc` (dev env), or invoke `/get-data-for-dev` for
   real prod-shaped data. The bar: the page must *demo well*, not merely render.
7. Produce the final clickable local link(s), record IDs included, `?cu=benguillet`
   appended.

### 7. Screenshots

`mkdir -p /tmp/sprint-demos/shots`. For every feature, capture 1–3 shots of the money
pages:

- **Local stack pages** — `agent-browser` (same tool as `/dogfood`; direct binary, never
  npx):
  ```bash
  agent-browser --session sprint-demos open "<local-url>?cu=benguillet"
  agent-browser --session sprint-demos wait --load networkidle
  agent-browser --session sprint-demos screenshot /tmp/sprint-demos/shots/<slug>.png
  ```
- **Prod pages** — these need Ben's real SSO session: use Claude-in-Chrome MCP (load via
  ToolSearch, call `tabs_context_mcp` first, open a NEW tab, navigate, screenshot). His
  Chrome is already authenticated. If Chrome tools aren't available, skip prod shots and
  note it — never enter credentials anywhere.

Crop nothing; full-page or viewport shots are fine. Name files by feature slug.

### 8. Build and publish the artifact deck

Build a **single self-contained HTML file** at
`/tmp/sprint-demos/sprint-demos-<SINCE_DATE>.html`:

- Slide-deck feel: header slide "Sprint demos — week of <window>, Ben", then one section
  per feature, then the "Also shipped" list. ←/→ keyboard navigation between sections plus
  normal scrolling; clean dark theme, YC-orange accent, big type — it will be projected.
- Per feature section: title, status badge (`LIVE IN PROD` / `PARTIAL` / `LOCAL DEMO`),
  the 1–2 sentence narrative, prominent buttons for the demo links (prod or local) and the
  MR/PR links, and the screenshots embedded as **base64 data URIs** (keep it single-file).
- Also save a copy into the current workspace's `.context/` directory.

Then publish to claude.ai:

1. First `ToolSearch` for an artifact/publish tool — if the harness ever grows one, use it.
2. Otherwise use Claude-in-Chrome: open `https://claude.ai/new`, attach or paste the HTML
   file with the instruction "Render exactly this HTML as an artifact, do not modify it",
   wait for the artifact to render, publish/copy the artifact link.
3. **Privacy reality check**: a published claude.ai artifact is viewable by ANYONE with
   the URL — there is no link-private mode. The deck contains YC-internal data, so this is
   acceptable only because the link is unguessable and handed only to Ben; say exactly
   this in the final report. If the deck ends up containing especially sensitive material
   (founder application content, private company metrics in screenshots), skip publishing,
   deliver the local HTML file only, and say why.
4. If browser publishing fails after 2–3 attempts, stop retrying: `open` the local HTML
   file instead and say the claude.ai step needs a manual paste.

### 9. Final report

The last message must contain everything (Ben only sees the final message). Format:

1. **TL;DR line**: "N features to demo (X live in prod, Y local), deck: <artifact link>".
2. **Per-feature table**: Feature | Status | Demo link (the one to click while presenting)
   | MRs/PRs.
3. Per-feature demo notes: the 1–2 sentence talk track + which record you staged and why.
4. **Also shipped** one-liners.
5. Housekeeping: which stacks were started (and that they're left running for the demo),
   what data was seeded, anything unverified (e.g. paxel prod status), and any feature
   whose demo setup failed and needs a manual look.

## Important Notes

- **Start local stacks as early as possible** (right after step 4 identifies the 🔴
  features) and do steps 5/7/8 while they boot.
- **Leave the demo stacks running** at the end — Ben is about to present from them.
- Merged ≠ deployed: a merge from 20 minutes ago is probably still rolling out. Re-check
  the healthcheck SHA right before finishing and update the status if it flipped.
- The deck must be presentable standalone: even if every screenshot fails, the links and
  narratives make it usable.
- If the window is empty (vacation week), say so plainly and offer a 2-week window.
