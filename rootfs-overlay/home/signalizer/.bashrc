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


# Don't put duplicate lines nor lines starting with space in the history file.
HISTCONTROL=ignoreboth

# Append to the history file; don't overwrite it.
shopt -s histappend

# Set history length.
HISTSIZE=10000
HISTFILESIZE=20000
