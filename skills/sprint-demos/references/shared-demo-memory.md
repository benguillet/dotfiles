# Shared Demo Memory

Read memos written during the sprint by the `save-demo-memo` skill before collecting or
re-fetching demo material.

## Layout

Use this structure:

```text
/Users/ben/Work/yc/reports/sprints/shared.demos/
└── <sprint-start YYYY-MM-DD>/
    ├── <captured-at UTC>-<slug>.md
    └── <captured-at UTC>-<slug>.assets/
        ├── screenshot.png
        └── artifact.html
```

Use the `SINCE_DATE` calculated by the skill's sprint-window logic as `sprint-start`.

## Compile-time memory pass

1. Read every markdown entry under `shared.demos/<SINCE_DATE>/` before querying GitLab,
   GitHub, analytics, or browsers. Inventory each linked local asset and note broken paths.
2. Seed feature grouping, talk tracks, links, record selection, analytics, and deck assets
   from these entries. A memory may justify a feature even when it has no matching MR/PR.
3. Reuse saved screenshots, HTML artifacts, links, and historical measurements directly.
   Do not recapture or refetch static material that is present and usable.
4. Refresh only facts whose current state matters to the presentation: open/merged status,
   production deployment, a link that is broken, or an explicitly current adoption number.
   Keep captured historical metrics as labeled snapshots.
5. If entries conflict, prefer the newest capture and mention the discrepancy. Never edit
   or delete capture entries during compilation.
6. In the final housekeeping note, report how many entries and assets were reused. List
   any skipped entry with a short reason.
