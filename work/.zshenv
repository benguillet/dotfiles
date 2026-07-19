# Load direnv for non-interactive shells (Claude Code, scripts, etc.).
# Interactive shells get direnv via the hook in ~/.zshrc; this covers the rest.
if command -v /opt/homebrew/bin/direnv >/dev/null 2>&1; then
  eval "$(/opt/homebrew/bin/direnv export zsh)" 2>/dev/null
fi
. "$HOME/.cargo/env"
