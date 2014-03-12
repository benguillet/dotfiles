HOMEBREW=/usr/local/bin:/usr/local/sbin
NPM=/usr/local/share/npm/bin
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/X11/bin:/usr/texbin

export SSL_CERT_FILE=/usr/local/opt/curl-ca-bundle/share/ca-bundle.crt
export PATH=$HOMEBREW:$NPM:$PATH
export EDITOR='vim'
export BUNDLER_EDITOR='subl'
export ARCHFLAGS="-arch x86_64"
