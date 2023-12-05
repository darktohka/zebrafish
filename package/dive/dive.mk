################################################################################
#
# dive
#
################################################################################

DIVE_VERSION = main
DIVE_SITE = $(call github,wagoodman,dive,main)
DIVE_LICENSE = MIT
DIVE_LICENSE_FILES = LICENSE

DIVE_GOMOD = github.com/wagoodman/dive

$(eval $(golang-package))
