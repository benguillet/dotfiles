# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="agnoster"
DEFAULT_USER="benjaminguillet"

# Editors
alias v='vim'
alias a='atom'
alias s='subl .'

# Misc aliases
alias fs='foreman start'
alias ll='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias df='df --human-readable'
alias du='du --human-readable'
alias yolo='git commit -am "#YOLO" && git push -f origin master'

# Turn off the special expansion of zsh for rake (hard brackets issue)
alias rake='noglob rake'
alias cdev='bundle exec cucumber --tags @dev'

# Tmux
alias tma='tmux attach -d -t'
alias tmn='tmux new -s'
alias tml='tmux list-sessions'
alias tmk='tmux kill-session -t'
alias tmr='tmux rename-session -t'
alias tmux="TERM=screen-256color-bce tmux"

alias lighty.start='lighttpd -f $HOME/.lighttpd.conf'
alias lighty.stop='killall lighttpd'
alias postgres.start='pg_ctl -D /usr/local/var/postgres -l logfile start'
alias postgres.stop='pg_ctl -D /usr/local/var/postgres -l logfile stop'
alias mongo.start="mongod --config /usr/local/etc/mongod.conf"
alias mysql.start='mysql.server start'
alias mysql.stop='mysql.server stop'
alias sound.restart="sudo kill -9 `ps ax | grep 'coreaudio[a-z]' | awk '{print $1}'`"
alias redis.start='redis-server /usr/local/etc/redis.conf'
alias memcached.start='memcached -vvv'
alias memcached.stop='killall memcached'

# Get external IP
alias ifconfig-ext='curl ifconfig.me'

# Set to this to use case-sensitive completion
# CASE_SENSITIVE="true"

# Comment this out to disable weekly auto-update checks
# DISABLE_AUTO_UPDATE="true"

# Uncomment following line if you want to disable colors in ls
# DISABLE_LS_COLORS="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
# COMPLETION_WAITING_DOTS="true"

# Bash-style interactive comments
setopt interactivecomments

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(git rbenv autojump brew rails rake-fast bundler gem sublime extract tmuxinator)

function gi() { curl http://gitignore.io/api/$@ ;}

# tmuxinator
[[ -s $HOME/.tmuxinator/scripts/tmuxinator ]] && source $HOME/.tmuxinator/scripts/tmuxinator
source $ZSH/oh-my-zsh.sh

