################################################################################
#
# crony
#
################################################################################

CRONY_VERSION = main
CRONY_SITE = $(call github,ClementNerma,Crony,main)
CRONY_LICENSE = Apache-2.0
CRONY_LICENSE_FILES = LICENSE.md

$(eval $(cargo-package))
