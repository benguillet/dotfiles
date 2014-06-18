HOMEBREW=/usr/local/bin:/usr/local/sbin
NPM=/usr/local/share/npm/bin
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/X11/bin:/usr/texbin

export GOPATH="$HOME/.go"
export RBENV_ROOT="$HOME/.rbenv"
export SSL_CERT_FILE=/usr/local/opt/curl-ca-bundle/share/ca-bundle.crt
export PATH=$HOMEBREW:$NPM:$GOPATH/bin:$PATH
export EDITOR='vim'
export BUNDLER_EDITOR='subl'
export ARCHFLAGS="-arch x86_64"
