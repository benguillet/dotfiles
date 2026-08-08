---
name: gdoc
description: >-
  Publish the latest version of a locally written spec / plan / design doc (markdown) to
  Google Docs and return the link. Typically invoked right after /draft-spec or
  /appops-tech-spec, or whenever the user says "publish to gdoc", "push this to google
  docs", "make a google doc of the spec", "update the gdoc", or wants the current on-disk
  version of a plan in Google Docs. Creates a new Doc on first publish and updates the same
  Doc in place on subsequent publishes.
---

# Publish a Spec to Google Docs

Publish the current on-disk version of a spec/plan markdown file as a Google Doc using the
`gws` CLI (Google Workspace CLI, `brew install googleworkspace-cli`), and give the user the
`webViewLink`. This uses the Drive API's native markdown import, so headings, bold, lists,
tables, and code blocks convert to real Doc formatting.

## 1. Find the file

The target is the spec/plan markdown written or edited most recently in this session
(usually by /draft-spec or /appops-tech-spec). If the user named a file, use that. If there
is no session context and no obvious candidate, ask which file to publish — don't guess
across unrelated documents.

Before publishing, make sure the file on disk reflects the latest state of the discussion:
if revisions were agreed in conversation after the last save, apply them to the file first.
The Doc is generated from the file, not from the chat.

Use the markdown's H1 as the Doc title (fall back to a humanized file name). Keep the title
stable across publishes — it's how an existing Doc is found for update.

## 2. Create or update?

- **Doc ID known from this session** (a previous publish printed `id`/`webViewLink`):
  update that Doc in place.
- **No known ID**: search Drive for an existing Doc with the exact title:

  ```bash
  gws drive files list --params '{"q": "name = \"<Title>\" and mimeType = \"application/vnd.google-apps.document\" and trashed = false", "fields": "files(id,name,webViewLink,modifiedTime)"}'
  ```

  If exactly one match and it plausibly came from an earlier publish of this same spec,
  confirm with the user before overwriting it — updating replaces the Doc's entire content,
  including any edits reviewers made directly in the Doc. If no match (or the user prefers a
  fresh copy), create a new Doc.

## 3. Prepare the upload copy

Publish from a **temp copy** of the markdown, not the source file, and apply this transform
to the copy:

- **Join the Author and Date lines with a backslash hard break.** Spec files keep a blank
  line between Author and Date (a bare newline is a markdown soft break and collapses to a
  space on Drive import). For the Doc we want them on two adjacent lines of one paragraph,
  so turn:

  ```
  [Author]

  [Date]
  ```

  into:

  ```
  [Author]\
  [Date]
  ```

  (backslash at end of the Author line, blank line removed). Drive's importer converts a
  backslash hard break into a same-paragraph line break (`\x0b` — a trailing-two-spaces
  break also works but editors strip it; `<br>` does NOT work, it produces two paragraphs
  with a blank one between). Skip the transform if the file has no Author/Date block.

The source `.md` keeps the blank line — it renders correctly everywhere else.

## 4. Commands

**`--upload` only accepts paths inside the current working directory** — always `cd` to the
file's directory first and pass a bare filename (for the temp copy, `cd` to its directory).

Create (first publish):

```bash
cd "$(dirname <spec.md>)" && gws drive files create \
  --json '{"name": "<Spec Title>", "mimeType": "application/vnd.google-apps.document"}' \
  --upload "$(basename <spec.md>)" \
  --upload-content-type text/markdown \
  --params '{"fields": "id,webViewLink"}'
```

Update in place (subsequent publishes — same link, content replaced):

```bash
cd "$(dirname <spec.md>)" && gws drive files update \
  --params '{"fileId": "<doc id>", "fields": "id,webViewLink"}' \
  --upload "$(basename <spec.md>)" \
  --upload-content-type text/markdown
```

Print the `webViewLink` from the JSON output as a clickable link, and say whether the Doc
was created or updated. Keep the `id` around in the conversation so later /gdoc runs in the
same session update rather than duplicate.

## 5. Failure handling

- **If `gws` is not installed or not authenticated** (`gws auth status` shows
  `"credential_source": "none"`), do NOT fail the skill. Deliver the local markdown path as
  the result and tell the user the one-time setup: `brew install googleworkspace-cli`, then
  run `! gws auth setup` themselves (interactive browser OAuth; creates the OAuth client) —
  or `! gws auth login` if already set up. Then offer to retry the publish.
- **403 "insufficient authentication scopes"** has two causes: (a) the Drive checkbox
  wasn't ticked on Google's consent screen — user must re-run
  `! gws auth login --services drive,docs` and tick every box; (b) a stale access token —
  `~/.config/gws/token_cache.json` older than `credentials.enc` means gws is sending a
  pre-re-consent token; delete the cache file and retry (it regenerates from the refresh
  token).
- **404 on update** — the remembered `fileId` is gone (doc trashed/deleted). Fall back to
  creating a new Doc and tell the user.
- Publishing is an outward-facing write — only run it after the user has seen the spec
  content (or explicitly asked for the doc up front). Never publish a half-finished draft.
