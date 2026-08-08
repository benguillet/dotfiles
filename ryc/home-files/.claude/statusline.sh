#!/bin/bash

input=$(cat)

ESC=$'\033'
RESET="${ESC}[0m"
DIM="${ESC}[2m"

BLUE=39
TEAL=44
GRAY=252
YELLOW=178
ORANGE=208
GREEN=70
RED=160
PURPLE=141
STAR_YELLOW=220
COST_TAN=180

c() { printf '%s' "${ESC}[38;5;$1m$2${RESET}"; }
lower() { tr '[:upper:]' '[:lower:]'; }

tier_color() {
  if [ "$1" -ge 80 ]; then
    printf '%s' "$RED"
  elif [ "$1" -ge 50 ]; then
    printf '%s' "$ORANGE"
  else
    printf '%s' "$GREEN"
  fi
}

fmt_tokens() {
  awk -v t="$1" 'BEGIN {
    if (t >= 1000000) { v = t / 1000000; if (v == int(v)) printf "%dm", v; else printf "%.1fm", v }
    else if (t >= 1000) { v = t / 1000; if (v == int(v)) printf "%dk", v; else printf "%.1fk", v }
    else printf "%d", t
  }'
}

parts=()

settings="$HOME/.claude/settings.json"

model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')
model_name=$(printf '%s' "$model_name" | lower)
# fast mode isn't in the statusline stdin JSON, so read the persisted setting
fast_mode=$(jq -r '.fastMode // false' "$settings" 2>/dev/null)
[ "$fast_mode" = "true" ] && model_name="${model_name} ⚡"
parts+=("$(c $BLUE "$model_name")")

# not `// empty`: jq's // treats false as null, which would eat enabled=false
thinking_enabled=$(echo "$input" | jq -r '.thinking.enabled | if . == null then "" else . end')
[ -z "$thinking_enabled" ] && thinking_enabled=$(jq -r '.alwaysThinkingEnabled // empty' "$settings" 2>/dev/null)
effort=$(echo "$input" | jq -r '.effort.level // empty')
[ -z "$effort" ] && effort=$(jq -r '.effortLevel // empty' "$settings" 2>/dev/null)

if [ "$thinking_enabled" = "false" ]; then
  parts+=("${DIM}thinking: off${RESET}")
elif [ -n "$effort" ]; then
  effort=$(printf '%s' "$effort" | lower)
  parts+=("${DIM}thinking: ${RESET}$(c $PURPLE "$effort")")
elif [ "$thinking_enabled" = "true" ]; then
  parts+=("${DIM}thinking: ${RESET}$(c $PURPLE on)")
fi

worktree=$(echo "$input" | jq -r '.worktree.name // .workspace.git_worktree // empty')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // empty')
[ -z "$worktree" ] && [ -n "$project_dir" ] && worktree=$(basename "$project_dir")
[ -n "$worktree" ] && parts+=("$(c $TEAL "$(printf '%s' "$worktree" | lower)")")

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
dir_name=""
[ -n "$cwd" ] && dir_name=$(basename "$cwd")
[ -n "$dir_name" ] && [ "$dir_name" != "$worktree" ] && parts+=("$(c $GRAY "$(printf '%s' "$dir_name" | lower)")")

if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    branch_display="$(c $GRAY "$(printf '%s' "$branch" | lower)")"
    # -uno skips the untracked-file scan, which is slow in this monorepo
    if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain -uno 2>/dev/null)" ]; then
      branch_display="${branch_display}$(c $STAR_YELLOW '*')"
    fi
    parts+=("$branch_display")
  fi
fi

used_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

if [ -z "$used_pct" ] && [ -n "$used_tokens" ] && [ -n "$context_size" ] && [ "$context_size" != "0" ]; then
  used_pct=$(awk -v u="$used_tokens" -v c="$context_size" 'BEGIN { printf "%.1f", (u / c) * 100 }')
fi

if [ -n "$used_tokens" ] && [ -n "$context_size" ]; then
  parts+=("$(c $YELLOW "$(fmt_tokens "$used_tokens")/$(fmt_tokens "$context_size")")")
elif [ -n "$used_tokens" ]; then
  parts+=("$(c $YELLOW "$(fmt_tokens "$used_tokens")")")
fi

if [ -n "$used_pct" ]; then
  pct_int=$(awk -v p="$used_pct" 'BEGIN { printf "%.0f", p }')
  parts+=("${DIM}ctx: ${RESET}$(c "$(tier_color "$pct_int")" "${pct_int}%")")
fi

cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
if [ -n "$cost" ]; then
  cost_display=$(awk -v c="$cost" 'BEGIN { printf "$%.2f", c }')
else
  cost_display='$0.00'
fi
parts+=("${DIM}cost: ${RESET}$(c $COST_TAN "$cost_display")")

# auth isn't in the statusline stdin JSON; infer like Claude Code does — env API
# key (inherited from the parent process) unless rejected, else claude.ai login
auth_display=""
if [ -n "$ANTHROPIC_API_KEY" ]; then
  key_prefix="${ANTHROPIC_API_KEY:0:20}"
  rejected=$(jq -r --arg p "$key_prefix" '.customApiKeyResponses.rejected // [] | index($p) != null' "$HOME/.claude.json" 2>/dev/null)
  if [ "$rejected" != "true" ]; then
    auth_display=$(c $ORANGE "key:…${ANTHROPIC_API_KEY: -4}")
  fi
fi
if [ -z "$auth_display" ]; then
  email=$(jq -r '.oauthAccount.emailAddress // empty' "$HOME/.claude.json" 2>/dev/null)
  [ -n "$email" ] && auth_display="${DIM}${email}${RESET}"
fi
[ -n "$auth_display" ] && parts+=("$auth_display")

output="${parts[0]}"
for part in "${parts[@]:1}"; do
  output="${output}${DIM} | ${RESET}${part}"
done

printf '%s\n' "$output"
