---
name: tag-infra
description: Tag the infra team (Mark Thurman @met1204, Emanuel Evans @shosti) as reviewers on a GitLab MR without any username lookups. TRIGGER when Ben says "/tag-infra", "tag infra on this", "tag mark and emanuel", "add infra reviewers", or any variation of wanting the infrastructure team tagged as reviewers on an MR.
---

# Tag Infra Reviewers

Assign the infrastructure team as reviewers on a GitLab MR. Usernames are fixed — do NOT look them up:

| Person | GitLab username |
|---|---|
| Mark Thurman | `met1204` |
| Emanuel Evans | `shosti` |

## Process

### 1. Identify the MR and repo

- Explicit IID in the args (e.g. `/tag-infra 1979`) → use it.
- Arg contains a GitLab MR URL → parse repo and IID from it.
- Otherwise → the open MR for the current branch:

  ```bash
  branch=$(git rev-parse --abbrev-ref HEAD)
  glab mr list --source-branch "$branch" -F json | jq -r '.[0].iid // empty'
  ```

Repo default is the current directory's repo. If the args mention "infra" with a bare IID and the current repo is not the infra repo, target `yc-software/infrastructure/infra` via `-R`.

If no MR is found, say so and stop.

### 2. Merge with existing reviewers

`glab mr update --reviewer` REPLACES the reviewer list, so fetch and merge first:

```bash
existing=$(glab [-R <repo>] mr view <IID> --output json | jq -r '[.reviewers[].username] | join(",")')
```

Combine `existing` + `met1204,shosti`, dedupe, and drop the MR author if present.

### 3. Update

```bash
glab [-R <repo>] mr update <IID> --reviewer <merged-list>
```

Confirm to Ben: "Tagged @met1204 and @shosti on <MR reference>" (mention any pre-existing reviewers kept).
