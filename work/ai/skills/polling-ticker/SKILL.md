---
name: polling-ticker
description: Use when Ben asks to monitor, poll, watch, or check something repeatedly — "monitor this every 10s", "check sentry every 2min for the next two hours", "watch the rollout and lmk when done", "poll until it's green", "confirm the restart is happening". TRIGGER on any monitor/poll/watch request with a frequency or duration, and on any watch longer than ~2 minutes even without one.
---

# polling-ticker

## Overview

When Ben asks for monitoring at a frequency, he is buying a **heartbeat**, not
just a result. He does not trust a quiet agent to still be polling — silence is
indistinguishable from "the agent stopped". A tick he cannot see did not happen.

**Core principle: every tick produces one user-visible status line, even when
nothing changed. Noise is the feature.**

## The contract

1. **One message per tick**, at the asked frequency:
   `15:45:43 — web IN_PROGRESS 8/8, worker IN_PROGRESS 7/7`
2. **Unchanged state is still a tick**: `15:45:55 — unchanged: web 8/8, worker 7/7`
3. **Errors are ticks too** — print the error on its tick, keep polling.
4. **End loudly** with an explicit final line:
   `✅ DONE 15:46:06 — both COMPLETED. GO for proxy restart.` or
   `⏹ Ticker stopped — 2h window elapsed, 0 new events.`
5. Never stop, slow down, batch ticks, or switch to report-on-change without
   announcing it first. If no frequency was given, pick one and announce it.

## Implementation (Claude Code)

Ticker = **Monitor** whose script emits one line per interval. Each stdout line
becomes a notification that re-invokes you → relay each as a one-line message.

```bash
while true; do
  s=$(aws ecs describe-services --cluster yc-prod \
    --services paxel-production-web paxel-production-worker \
    --query 'services[].[serviceName,deployments[0].rolloutState,runningCount]' \
    --output text | tr '\n\t' '  ')
  echo "$(date +%H:%M:%S) — ${s:-poll failed, retrying}"
  sleep 10
done
```

- Emit the line **unconditionally** — do not filter to changes or "signal".
  Ben's frequency request overrides the Monitor tool's filter-the-noise
  guidance: the heartbeat IS the signal.
- Make the script `exit` on terminal state (or bound the window:
  `[ $SECONDS -gt 7200 ] && exit`) so the last notification is the DONE line.
- `timeout_ms` maxes at 1h — for longer windows use `persistent: true` plus a
  window bound in the script.
- Relay every notification as its own one-line message; never summarize
  several ticks into one.
- If the harness suppresses or kills the monitor for output volume, tell Ben
  immediately and restart it (or fall back to foreground polling: one poll
  tool call per tick, one status line after each). Never silently downgrade.

## Red flags — you are about to violate the contract

- "My background monitor will notify me when it completes"
- "I'll report when it changes / when it's done"
- "Still waiting — no news is good news"
- "To reduce noise I'll only post transitions"
- More than one interval has passed since your last visible line

All of these mean: emit a tick line **now**, then fix the ticker.
