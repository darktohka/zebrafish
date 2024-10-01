################################################################################
#
# zrepl
#
################################################################################

ZREPL_VERSION = master
ZREPL_SITE = $(call github,darktohka,zrepl,master)
ZREPL_LICENSE = MIT
ZREPL_LICENSE_FILES = LICENSE

ZREPL_GOMOD = github.com/zrepl/zrepl

$(eval $(golang-package))
