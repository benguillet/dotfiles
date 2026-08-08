# Paxel Privacy Sources

## Paxel repository

| Material | Source |
|---|---|
| Binding Privacy Policy | `app/views/home/_privacy_body.html.erb` |
| Privacy page wrapper | `app/views/home/privacy.html.erb` |
| Current technical disclosure | `app/views/home/data_handling.html.erb` |
| Website FAQ | `app/views/home_v3/show.html.erb`, `hv3_faqs` |
| Disclosure regression coverage | `spec/views/data_handling_disclosure_spec.rb` |
| Privacy request coverage | `spec/requests/privacy_spec.rb`, `spec/requests/data_handling_spec.rb` |

Find pending policy/disclosure work with:

```zsh
gh pr list --repo yc-software/paxel --state open --limit 100 \
  --json number,title,headRefName,baseRefName,url,updatedAt
```

Inspect the PR body, files, and diff. Fetch the selected PR into a read-only remote ref before running the collector.

## YC code monorepo

| Material | Source |
|---|---|
| Apply state selection and copy | `apply/app/javascript/src/components/paxel/BuilderProfileSection.tsx` |
| No-account promo | `apply/app/javascript/src/components/paxel/PaxelPromoCard.tsx` |
| Linked card copy | `apply/app/javascript/src/components/paxel/PaxelConnectedCard.tsx` |
| Account-link card and waiting copy | `apply/app/javascript/src/components/paxel/PaxelLinkAccountCard.tsx` |
| State enum | `apply/app/javascript/src/components/hooks/usePaxelState.ts` |
| Reminder trigger | `ycinternal/app/models/applicant.rb` |
| Reminder headers and subject | `ycinternal/app/mailers/apps_mailer.rb` |
| Reminder body | `ycinternal/app/views/mailers/apps_mailer/paxel_report_reminder.html.slim` |
| Apply support FAQ | `ycinternal/db/migrate/20260725024227_add_paxel_faq_to_apply_front_agent.rb` |

The canonical Apply-state design document is:

`https://docs.google.com/document/d/1mR5_4EoWQxdAihfsLtVJRLkT3J0DxfXF1IcLT7zFIR4/edit`

Use it for visual references. Current merged source code remains authoritative for text.

## Source discovery

Do not assume the repos live at old project-document paths. Locate candidates, then verify:

```zsh
git -C /candidate/path remote -v
git -C /candidate/path status --short --branch
```

Use `origin/main` for Paxel and `origin/master` for YC code unless the user names another source.

## Publication

Build rich HTML first so headings, lists, tables, links, code spans, and policy structure survive Google Docs paste. Keep the first tab as a short provenance/index page. Include source dates and links near each document title.

When a Docs API cannot access the target document, use the signed-in browser. Create top-level document tabs, paste rich HTML, insert state screenshots, visually inspect representative pages, and preserve the target tab as the deliverable.
