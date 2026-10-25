# Minimal clean bashrc for guest sandbox
export PS1="\[\033[1;36m\][guest-sandbox]\[\033[0m\] \w \$ "
export BROWSER="/usr/bin/brave-origin"
export PATH="/usr/local/bin:/usr/bin"
umask 077
alias browser="brave-origin"
