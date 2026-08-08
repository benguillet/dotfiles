---
name: travel-preferences
description: Use when any travel planning, searching, comparing, or booking task arises — flights, hotels, trains, car rentals, or full trips — to route to Ben's specific travel preference skills before presenting options.
---

# Travel Preferences (Routing Table)

Entry point for Ben's personal travel preferences. This skill holds no preferences itself — it routes to the specific preference skill for each travel domain. Add a row here whenever a new domain-specific preference skill is created.

## Routing table

| Travel domain | Skill to load | Notes |
|---|---|---|
| Flights (search, awards, booking, comparison) | `flight-preferences` | Timing, routing, red-eye, Wi-Fi rules + route-specific plays (e.g. SFO↔NTE) |
| Hotels | — | No skill yet; ask Ben and create one when preferences emerge |
| Trains / ground transport | — | No skill yet |
| Car rentals | — | No skill yet |

## Points inventory

Ben holds transferable points in **Chase Ultimate Rewards** and **Capital One** only. Gate award-booking transfer paths to programs reachable from these two currencies; ignore Citi/Amex/Bilt-only bonuses.

## How to apply

- Any flight-related preference question routes to `flight-preferences` — do not duplicate flight rules here.
- When Ben states a new durable travel preference, add it to the matching domain skill (create the skill if it doesn't exist), then register it in the routing table above.
- Skills live in `~/dotfiles/perso/ai/skills/` (version-controlled) and are symlinked into `~/.claude/skills/` and `~/.codex/skills/`.
