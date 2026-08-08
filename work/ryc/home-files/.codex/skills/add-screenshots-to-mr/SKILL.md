---
name: add-screenshots-to-mr
description: Take screenshots of the frontend changes built in this session/branch and attach them to the corresponding GitLab MR. TRIGGER when the user says "add screenshots to mr", "screenshot the changes and put them on the mr", "attach screenshots", "add screenshots to the merge request", or any variation of wanting to capture the UI that was built and post it to the MR. If there are no frontend changes, says so and stops.
---

# Add Screenshots to MR

Capture screenshots of the frontend changes made in this session/branch and attach them to the corresponding GitLab merge request. If nothing frontend-facing changed, tell the user and stop — don't take screenshots or touch the MR.

## User's Request

$ARGUMENTS

## Process

### 1. Detect frontend changes

Diff the branch against **the MR's actual target branch**, not a hardcoded `master`. Determine the base first, then diff:

```bash
# Prefer the MR's target branch; fall back to the repo default, then master.
branch=$(git rev-parse --abbrev-ref HEAD)
target=$(glab mr list --source-branch "$branch" -F json 2>/dev/null | jq -r '.[0].target_branch // empty')
[ -z "$target" ] && target=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
[ -z "$target" ] && target=master
git fetch origin "$target" --quiet 2>/dev/null
git diff "origin/$target...HEAD" --name-only
```

Treat a change as **frontend** if it touches a UI-rendering file. Match by **extension**, since UI lives in many places across this monorepo (`*/app/javascript/`, `bookface/app/frontend/`, `shared/frontend/`, `ycapp/src/`, `ycapp/app/`, `hermes-chat-ui/`, `hermes-webui/`, etc.) — don't restrict to a single directory:

- `**/*.tsx`, `**/*.ts`, `**/*.jsx`, `**/*.js` (excluding the non-UI exclusions below)
- `**/*.scss`, `**/*.css`
- `**/*.vue`, `**/*.svelte`
- `**/*.erb`, `**/*.haml`, `**/*.slim` under `app/views/`

Ignore these even if they match the extensions above — they don't render UI:

- test files (`*.test.ts(x)`, `*.spec.ts(x)`, anything under `test/`, `spec/`, `__tests__/`)
- generated files (`__generated__/`, `*.d.ts`, route helpers, generated serializers/zod)
- config/build files (`*.config.ts`, `vite.config.*`, `tailwind.config.*`, etc.)
- non-UI JS/TS: Node scripts, build tooling (`buildGen/`, `scripts/`, `tools/`), `lambdas/`, CLI code, and server-only modules

Also use **session context**: if you built or edited a specific page/component in this conversation, prefer that as the thing to screenshot. The diff is the source of truth for *whether* there are frontend changes; the session is the best guide for *what the change looks like* and *which page shows it*.

**If there are no frontend changes:** stop here — **unless** the user explicitly passed a URL or page name in `$ARGUMENTS` (see Options). An explicit target overrides the diff guard: screenshot that page regardless of what the diff contains. Only when there's no frontend change *and* no explicit target do you stop and tell the user plainly, e.g.:

> No frontend changes detected on this branch (only backend/test/config files changed), so there's nothing to screenshot. Let me know if you want screenshots of a specific page anyway.

Do not proceed to the remaining steps in that case.

### 2. Find the corresponding MR (fail fast)

Before doing any screenshot work, confirm an MR exists for the branch so you don't capture screenshots only to discover there's nowhere to put them:

```bash
branch=$(git rev-parse --abbrev-ref HEAD)
glab mr list --source-branch "$branch" -F json | jq -r '.[0].iid // empty'
```

- If **no MR exists** for the branch, stop here — tell the user and offer to run `/mr` first, then come back. Don't create the MR yourself unless they ask, and don't capture screenshots.
- If an MR exists, store its IID as `MR_IID` and continue.

### 3. Figure out what to screenshot

For each meaningful frontend change, identify the page(s) that render it, then capture the feature **actually working** across the states below. Capture each state **when it's relevant to the change** — don't force a state that doesn't apply (e.g. a static marketing page has no error path).

- **Feature working / happy path** — always capture this. Show the change doing its job with realistic data: the populated list, the successful form submission, the rendered component in its normal state. This is the core screenshot.
- **Empty state** — when the change involves a list, table, search, feed, or anything that can have zero items. Capture it with no data so reviewers see the empty/zero state (use a record/filter that yields nothing, or clear the data).
- **Error path** — when the change can fail or validate input: invalid form submission, a failed request, a permission/forbidden state, a not-found, etc. Trigger the error (submit bad input, hit the failing condition) and capture the error UI (inline validation, error banner, toast, fallback).

Practical notes:

- Map changed components/pages to the route(s) that display them (grep for the component in routes, controllers, or parent components if it's not obvious).
- If a change only shows up under specific data conditions, use a record that satisfies them (and a different record/filter for the empty state).
- If you changed a modal/dropdown/expandable, open it before capturing.
- Briefly note which states you judged relevant and which you skipped (and why) so the user can ask for more if needed.

### 4. Get the local dev URL and real record IDs

Per the user's global preference, build links against the **local dev server** and never hardcode host/port:

```bash
yc stacks url
```

Use **real record IDs** from the data the change touches (app, company, user, interview, etc.), not `:id` placeholders. If you don't have a concrete ID, query for one (use the `/rc` skill or a `yc-*` data skill) rather than guessing. Construct the full URL(s) for each page/state you plan to capture.

### 5. Take the screenshots

First create the output directory so captures don't fail on a missing parent folder:

```bash
mkdir -p /tmp/mr-screenshots
```

Then use whatever browser tooling is available, in this order of preference:

1. **`agent-browser`** (the tool the `/dogfood` skill uses):
   ```bash
   agent-browser --session screenshots-mr open "<URL>"
   agent-browser --session screenshots-mr wait --load networkidle
   agent-browser --session screenshots-mr screenshot /tmp/mr-screenshots/<name>.png
   ```
2. **Claude-in-Chrome MCP** — if `agent-browser` isn't installed, load the tools first with ToolSearch (`select:mcp__claude-in-chrome__tabs_context_mcp`, `..._navigate`, `..._take_screenshot`), then navigate to each URL and capture. Call `tabs_context_mcp` first and open a **new** tab for this work.

Save screenshots to a temp dir (e.g. `/tmp/mr-screenshots/`). Guidelines:

- Wait for the page to fully load before capturing (network idle).
- If the page requires login, sign in (ask the user for credentials/OTP only if needed).
- Give each file a descriptive name tied to the **change and the state** it shows (e.g. `company-card-happy-path.png`, `company-list-empty-state.png`, `company-form-validation-error.png`).
- Capture each relevant state from step 3 — the working/happy path always, plus the empty state and error path when they apply. Drive the UI into each state before capturing (clear data for empty, submit bad input or trigger the failure for error).
- For before/after comparisons, only capture "after" unless the user asks for both (you'd need to stash changes for "before").
- Take a couple of extra/scoped shots if the change is subtle so reviewers can actually see it.

If the browser tooling fails after 2–3 attempts, stop and tell the user what went wrong rather than looping.

### 6. Upload screenshots and attach to the MR

Upload each screenshot to the project's uploads endpoint, which returns embeddable markdown.

**Do NOT use `glab api --method POST projects/:fullpath/uploads --field "file=@…"`.** `glab api` sends the file as a string field, not a multipart upload, so GitLab rejects it with `HTTP 400`. The uploads endpoint requires real multipart, so use `curl`.

Set up host, project, and token once (works for gitlab.com and self-hosted):

```bash
HOST=$(git remote get-url origin | sed -E 's#^[a-z]+://##; s#^git@##; s#[:/].*$##')
[ -z "$HOST" ] && HOST=gitlab.com
PROJECT=$(glab repo view -F json 2>/dev/null | jq -r '.full_name // .path_with_namespace // empty')
ENC=$(printf '%s' "$PROJECT" | sed 's#/#%2F#g')
# Use --host, NOT -h: `-h` is --help and prints usage text instead of the token.
# Trim whitespace; the value can have a trailing newline.
TOKEN=$(glab config get token --host "$HOST" 2>/dev/null | tr -d '[:space:]')
```

Upload helper (glab's token is usually an **OAuth** token → `Authorization: Bearer`; it falls back to `PRIVATE-TOKEN` for a personal access token):

```bash
upload() {  # $1 = file path; prints the markdown ref on success
  local resp
  resp=$(curl -s --request POST --header "Authorization: Bearer $TOKEN" \
    --form "file=@$1" "https://$HOST/api/v4/projects/$ENC/uploads")
  echo "$resp" | jq -e '.markdown' >/dev/null 2>&1 || \
    resp=$(curl -s --request POST --header "PRIVATE-TOKEN: $TOKEN" \
      --form "file=@$1" "https://$HOST/api/v4/projects/$ENC/uploads")
  echo "$resp" | jq -r '.markdown // .message // "UPLOAD_FAILED"'
}

upload /tmp/mr-screenshots/<name>.png
```

Each call returns a markdown image reference like `![name](/uploads/<hash>/name.png)`. Collect one per screenshot.

> If `curl` returns `HTTP 000` / "couldn't connect" while `glab` itself works, your shell sandbox is blocking curl's outbound network — re-run the upload with the network/sandbox restriction lifted (e.g. Claude Code: `dangerouslyDisableSandbox`).

Then add them to the MR. **Default: put a Screenshots section in the MR description** (that's where reviewers expect them). Fetch the current description and preserve everything *except* a previous `## Screenshots` section — strip any existing one first so re-running the skill **replaces** the screenshots instead of stacking duplicate sections, then append the fresh section:

Build the new Screenshots section in a file first (one caption + image ref per screenshot), then merge it into the description with `jq` so quotes, backticks, or `$` already in the description are never re-interpreted by the shell:

```bash
# 1. Write the fresh "## Screenshots" section to a file.
cat > /tmp/mr-screenshots/section.md <<'EOF'
## Screenshots

<caption 1>

![...](/uploads/.../one.png)

<caption 2>

![...](/uploads/.../two.png)
EOF

# 2. Strip any previously-added "## Screenshots" section (from that heading to EOF or the
#    next "## " heading) so re-runs replace rather than stack.
glab mr view "$MR_IID" -F json | jq -r '.description // ""' | awk '
  /^## Screenshots[[:space:]]*$/ { skip=1; next }
  skip && /^## / { skip=0 }
  !skip { print }
' > /tmp/mr-screenshots/desc-without-old.md

# 3. Concatenate with jq --rawfile (no shell re-interpretation of the existing text).
new_description=$(jq -rn \
  --rawfile base /tmp/mr-screenshots/desc-without-old.md \
  --rawfile shots /tmp/mr-screenshots/section.md \
  '($base | rtrimstr("\n")) + "\n\n" + $shots')
glab mr update "$MR_IID" --description "$new_description"
```

This assumes the Screenshots section is the last `## ` section (the skill always appends it). If the description places another `## ` heading after it, the awk above stops stripping at that heading and preserves it. Give each screenshot a one-line caption describing what it shows / which state it is.

If the user passed `as-comment` in `$ARGUMENTS`, post a comment instead of editing the description. To avoid stacking duplicate comments on re-runs, include a stable marker and **update an existing screenshots comment** (or delete prior ones) rather than always creating a new note:

```bash
# Reuse the section file from above, prefixed with a stable marker.
{ echo "<!-- mr-screenshots -->"; cat /tmp/mr-screenshots/section.md; } > /tmp/mr-screenshots/comment.md

# Find prior screenshots comment(s) authored by the current user. --paginate walks ALL
# pages, so a marker comment past the first 100 notes is still found.
me=$(glab api user | jq -r '.username')
existing=$(glab api --paginate "projects/:fullpath/merge_requests/$MR_IID/notes?per_page=100" \
  | jq -r --arg me "$me" '.[] | select(.author.username==$me and (.body | contains("<!-- mr-screenshots -->"))) | .id')

if [ -n "$existing" ]; then
  # Update the first match in place; delete any extra duplicates.
  first=$(printf '%s\n' "$existing" | head -1)
  glab api --method PUT "projects/:fullpath/merge_requests/$MR_IID/notes/$first" \
    --field "body=$(cat /tmp/mr-screenshots/comment.md)" >/dev/null
  printf '%s\n' "$existing" | tail -n +2 | while read -r dup; do
    glab api --method DELETE "projects/:fullpath/merge_requests/$MR_IID/notes/$dup" >/dev/null
  done
else
  glab mr note "$MR_IID" --message "$(cat /tmp/mr-screenshots/comment.md)"
fi
```

### 7. Report back

Tell the user what you did: which states you captured, and a link to the MR. Include the MR URL (`glab mr view "$MR_IID" -F json | jq -r '.web_url'`).

## Options

Parse `$ARGUMENTS` for:

- `as-comment` — attach screenshots as an MR comment instead of editing the description.
- A URL or page name — screenshot that specific page instead of (or in addition to) auto-detecting from the diff. This **overrides the no-frontend-changes guard** in step 1: if the user names a page, screenshot it even on a backend-only branch.

## Important Notes

- **No frontend changes → no screenshots**, *unless the user explicitly names a page/URL* (then screenshot that). This is the primary guard. Don't take screenshots of unrelated pages just to have something to post.
- **Local dev server only**, and **real record IDs** — never `:id` placeholders (per the user's global preference for the YC monorepo).
- **Never clobber the MR description.** Always fetch, append, then update.
- **Uploads use `curl` multipart with glab's token as a `Bearer` header**, not `glab api --field file=@…` (that sends a string field and 400s). Read the token with `glab config get token --host <host>` (`--host`, not `-h`).
- **Don't create the MR.** If there's no MR for the branch, ask the user to run `/mr` first.
- Don't trigger JavaScript dialogs/alerts in the browser; they block automation.
