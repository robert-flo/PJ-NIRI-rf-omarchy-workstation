# Clean bashrc for Btrfs sandbox
export PS1="\[\033[1;35m\][sandbox-btrfs]\[\033[0m\] \w \$ "
export BROWSER="/usr/bin/brave-origin"
export PATH="/usr/local/bin:/usr/bin"
umask 077

# Utilidades de audio rápidas
alias vol="wpctl get-volume @DEFAULT_AUDIO_SINK@"
alias mute="wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
alias reboot="systemctl reboot"
alias poweroff="systemctl poweroff"
