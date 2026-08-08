---
name: pier70-lunch
description: Use when Ben wants his office lunch handled. TRIGGER when Ben says "/pier70-lunch", "order my office lunch", "pier70 lunch", "add me to the lunch order", "arm the lunch routine", or when a scheduled weekday-morning lunch cron prompt fires.
---

# Pier 70 Office Lunch

Add Ben's most likely pick to the office DoorDash group order posted each
weekday in #pier70-doordash — only after his explicit confirmation in this
session, never without it.

Two modes: **run** (default — handle today's lunch) and **arm** (schedule the
weekday cron; use when Ben says "arm").

## Known facts — do NOT re-discover these

- Channel: #pier70-doordash, ID `C05DUB77KJT`. Read with
  `mcp__claude_ai_Slack__slack_read_channel` (ToolSearch-load it first).
- The lunch post lands at 7:30:01am PT sharp on weekdays: "<!channel> lunch!"
  + two restaurant names (each with an emoji) + two
  `https://drd.sh/cart/<code>/` group-cart links.
- Ordering closes at **10:00am PT** — the post does NOT state this; a "15 min
  left" warning lands ~9:45am. Treat 10:00 as a hard deadline.
- **dd-cli CANNOT join, inspect, or edit group carts.** No such command
  exists — do not attempt it with `cart` commands (those build personal
  carts). The ONLY way to add to a shared cart is the browser
  (Claude-in-Chrome) on the drd.sh link.
- An already-checked-out cart link redirects to
  `doordash.com/home?groupCartCheckedOut=true` — means too late (or stale link).
- Ben is normally signed OUT of doordash.com in Chrome. Group carts accept
  guest participants — join with the name "Ben". NEVER enter credentials; if
  the page hard-requires sign-in, stop and ask Ben to sign in himself, then
  continue.

## Run mode

1. Read channel `C05DUB77KJT`; find TODAY's lunch post; extract both
   restaurant names + drd.sh links. Not posted yet → ScheduleWakeup ~4 min
   and re-check until 8:30am, then notify Ben and stop (likely holiday).
   Slack cannot be watched with Monitor — poll.
2. Pick restaurant + item — recency, not frequency:
   - `~/.local/bin/dd-cli --json-output order history`, fuzzy-match both
     restaurant names against `store_name`. One match → Ben's MOST RECENT
     order there, items verbatim. Both match → the more recently ordered one.
   - No match → taste profile below.
   - Still ambiguous → present both restaurants as options instead of a
     recommendation.
3. Confirm — hard gate. PushNotification, then AskUserQuestion: recommended
   item @ restaurant (price if known), the other restaurant as an option,
   "something else", "skip today". No reply by 9:30 → one more push citing
   the 10:00 cutoff. No reply by 10:00 → do nothing; report it as missed.
4. Only after the yes: open the chosen drd.sh link in Claude-in-Chrome.
   If something from Ben is already in the cart, stop and report (no
   double-adds). Add the confirmed item; join as guest "Ben" if prompted.
   Confirmed item not on the menu → find closest match and re-confirm with
   Ben BEFORE adding.
5. Verify the line item shows in the cart, screenshot it, report:
   restaurant, item, price, proof.

Rules: one item, one cart. NEVER check out / submit the group order or touch
payment — the organizer does that. Read-only on Slack. No cart write without
explicit confirmation given in this session.

## Arm mode

`CronCreate` with cron `40 7 * * 1-5`, prompt: "Invoke the pier70-lunch skill
(Skill tool) and follow its run mode." Then tell Ben: the cron is
session-local (dies when the session closes) and auto-expires after 7 days —
re-arm weekly or from any new session.

## Taste profile (agreed with Ben, 2026-07)

1. Margherita / classic plain pizza on the menu → that's the pick (16 of his
   last 39 orders).
2. Otherwise one classic comfort entrée: breakfast plate, California-style
   burrito, cheeseburger + fries, chicken sandwich (+ fries), garlic noodles,
   butter chicken + naan, burrito bowl.
3. No drinks, no salads; dessert only if cookies.

## Gotchas

| Symptom | Meaning / fix |
|---|---|
| Tempted to use dd-cli `cart add-items` for the shared cart | Wrong — that builds Ben's personal cart. Browser only. |
| drd.sh link → `groupCartCheckedOut=true` | Cart already checked out — too late today. |
| DoorDash sign-in wall on the cart page | Try guest join first; else ask Ben to sign in himself. NEVER enter credentials. |
| No lunch post by 8:30 on a weekday | Holiday / no lunch day — notify Ben and stop. |
| Restaurant matches history but item missing from menu | Closest match + re-confirm before adding. |
