#  WHOA, CAREFUL THERE...
#
#  Yes, it's tempting to edit this file.
#  But if if is edited on a system with
#  persistence enabled, it will overlay
#  the original on the Zebrafish rootfs.
#  This will effectively prevent a newer
#  version of Zebrafish from providing
#  an updated of this file though its
#  rootfs.
#
#  Edit your ~/.profile and override from
#  there instead; Zebrafish does not
#  manage that.


# Safety first.
alias rm='rm -iv'
alias cp='cp -aiv'
alias mv='mv -iv'

# Convenience.
alias ls='ls --color=auto --group-directories-first'
alias ll='ls -l'
alias lla='ll -a'
alias llh='ll -h'
alias df='df -h'
alias du='du -sch'

# More convenience, since Zebrafish is Docker-centric.
alias d='docker'
alias d-c='docker compose'
alias docker-compose='docker compose'

export PAGER="/usr/bin/less"  # Less is more, only better.
export EDITOR="/usr/bin/nano"

# Add user-specific colors to the prompt to indicate that this is an important system.
[ $(id -u) -ne 0 ] || export PS1="\[\e[1;31m\]\u@\h:\[\e[0m\]\w\\$ "
[ $(id -u) -eq 0 ] || export PS1="\[\e[0;32m\]\u@\h:\[\e[0m\]\w\\$ "

# Auto-logout idle root shell.
[ $(id -u) -ne 0 ] || export TMOUT=300
