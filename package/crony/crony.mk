################################################################################
#
# crony
#
################################################################################

CRONY_VERSION = main
CRONY_SITE = $(call github,darktohka,Crony,main)
CRONY_LICENSE = Apache-2.0
CRONY_LICENSE_FILES = LICENSE.md

# Disable builtin cpio
define ROOTFS_CPIO_CMD
endef

$(eval $(cargo-package))
