# Start configuration added by Zim install {{{
#
# User configuration sourced by interactive shells
#

# -----------------
# Zsh configuration
# -----------------

#
# History
#

# Remove older command from the history if a duplicate is to be added.
setopt HIST_IGNORE_ALL_DUPS

#
# Input/output
#

# Set editor default keymap to emacs (`-e`) or vi (`-v`)
bindkey -e

# Prompt for spelling correction of commands.
#setopt CORRECT

# Customize spelling correction prompt.
#SPROMPT='zsh: correct %F{red}%R%f to %F{green}%r%f [nyae]? '

# Remove path separator from WORDCHARS.
WORDCHARS=${WORDCHARS//[\/]}

# -----------------
# Zim configuration
# -----------------

# Use degit instead of git as the default tool to install and update modules.
#zstyle ':zim:zmodule' use 'degit'

# --------------------
# Module configuration
# --------------------

#
# git
#

# Set a custom prefix for the generated aliases. The default prefix is 'G'.
#zstyle ':zim:git' aliases-prefix 'g'

#
# input
#

# Append `../` to your input for each `.` you type after an initial `..`
#zstyle ':zim:input' double-dot-expand yes

#
# termtitle
#

# Set a custom terminal title format using prompt expansion escape sequences.
# See http://zsh.sourceforge.net/Doc/Release/Prompt-Expansion.html#Simple-Prompt-Escapes
# If none is provided, the default '%n@%m: %~' is used.
#zstyle ':zim:termtitle' format '%1~'

#
# zsh-autosuggestions
#

# Disable automatic widget re-binding on each precmd. This can be set when
# zsh-users/zsh-autosuggestions is the last module in your ~/.zimrc.
ZSH_AUTOSUGGEST_MANUAL_REBIND=1

# Customize the style that the suggestions are shown with.
# See https://github.com/zsh-users/zsh-autosuggestions/blob/master/README.md#suggestion-highlight-style
#ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'

#
# zsh-syntax-highlighting
#

# Set what highlighters will be used.
# See https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters.md
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

# Customize the main highlighter styles.
# See https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters/main.md#how-to-tweak-it
#typeset -A ZSH_HIGHLIGHT_STYLES
#ZSH_HIGHLIGHT_STYLES[comment]='fg=242'

# ------------------
# Initialize modules
# ------------------

ZIM_HOME=${ZDOTDIR:-${HOME}}/.zim
# Download zimfw plugin manager if missing.
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  if (( ${+commands[curl]} )); then
    curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  else
    mkdir -p ${ZIM_HOME} && wget -nv -O ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  fi
fi
# Install missing modules, and update ${ZIM_HOME}/init.zsh if missing or outdated.
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZDOTDIR:-${HOME}}/.zimrc ]]; then
  source ${ZIM_HOME}/zimfw.zsh init -q
fi
# Initialize modules.
source ${ZIM_HOME}/init.zsh

# ------------------------------
# Post-init module configuration
# ------------------------------

# Allow `>` to overwrite existing files without requiring `>|`.
# This speeds up LLMs, which otherwise get tripped up by the clobber error.
# Must come after Zim init: the environment module sets NO_CLOBBER.
unsetopt noclobber

#
# zsh-history-substring-search
#

zmodload -F zsh/terminfo +p:terminfo
# Bind ^[[A/^[[B manually so up/down works both before and after zle-line-init
for key ('^[[A' '^P' ${terminfo[kcuu1]}) bindkey ${key} history-substring-search-up
for key ('^[[B' '^N' ${terminfo[kcud1]}) bindkey ${key} history-substring-search-down
for key ('k') bindkey -M vicmd ${key} history-substring-search-up
for key ('j') bindkey -M vicmd ${key} history-substring-search-down
unset key
# }}} End configuration added by Zim install


# Editors
alias v='vim'
alias c='cursor .'
alias cat='bat'

# Git
alias gst='git status'
alias com='git commit'
alias pullh='git pull https_origin'
alias pushh='git push https_origin'
alias push='git push'
alias pull='git pull'
alias gsb='git status -s'
alias lg='lazygit'

# Delete already merged branches
alias gcn="git-delete-merged-branches --effort=3 --branch master"
alias wip='com -S -n -m "WIP"'
alias pr='gh pr create --fill --reviewer couscous18'

# fzf: Checkout a branch (sorted by most recent commit)
alias gcb='git for-each-ref --sort=-committerdate refs/heads/ --format="%(refname:short)" | sed "s/^origin\///" | awk "!seen[\$0]++" | fzf -0 --preview "git show --color=always {}" | xargs -r git checkout'

# Misc aliases
alias la='eza -a'
alias ll='eza -l'
alias lla='eza -la'

# Turn off the special expansion of zsh for rake (hard brackets issue)
alias rake='noglob rake'
alias be='bundle exec'

# Docker
alias comp='docker compose'

# Zellij (Tmux replacement)
alias ze='zellij'
alias zma='zellij attach'
alias zmn='zellij -s'
alias zml='zellij list-sessions'
alias zmk='zellij kill-session'

# Map zoxide to old autojump alias
alias j='z'

# Libpq
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

# brew wrapper: records `brew install`s into the work Brewfile (must precede
# /opt/homebrew/bin so the wrapper shadows the real brew)
export PATH="$HOME/Work/dotfiles/work/scripts:$PATH"

# Overriden value from the zimrc/environment plugin
HISTSIZE=500000 # Default 20k
SAVEHIST=400000 # Default 10k

# Like autojump, but better
eval "$(zoxide init zsh)"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/ben/.cache/lm-studio/bin"

# Mise (maybe replace with plugins)
eval "$(/opt/homebrew/bin/mise activate zsh)"

#. "$HOME/.local/bin/env"

# bun completions
[ -s "/Users/ben/.bun/_bun" ] && source "/Users/ben/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# pnpm
export PNPM_HOME="/Users/ben/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
eval "$(rbenv init -)"
export NVM_DIR="/Users/ben/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

# Scratch
export PATH="/Users/ben/.local/bin:$PATH"

# direnv: load per-directory env from .envrc / .env (must be last so it hooks
# after other shell setup).
eval "$(direnv hook zsh)"

# Added by Devin
export PATH="/Users/ben/.codeium/windsurf/bin:$PATH"
