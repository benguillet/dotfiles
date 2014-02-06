ANDROID_HOME=/Applications/adt-bundle-mac-x86_64-20130219
HOMEBREW=/usr/local/bin:/usr/local/sbin
NPM=/usr/local/share/npm/bin
GEM=/usr/local/opt/rbenv/versions/1.9.3-p392/lib/ruby/gems/1.9.1
HEROKU=/usr/local/heroku/bin
RBENV=~/.rbenv/shims

PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/X11/bin:/usr/texbin:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools

export SSL_CERT_FILE=/usr/local/opt/curl-ca-bundle/share/ca-bundle.crt
export PATH=$HEROKU:$RBENV:$HOMEBREW:$GEM:$NPM:$PATH
export EDITOR='vim'
export BUNDLER_EDITOR='subl'
export ARCHFLAGS="-arch x86_64"
