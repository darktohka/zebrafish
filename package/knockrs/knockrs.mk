################################################################################
#
# knockrs
#
################################################################################

KNOCKRS_VERSION = master
KNOCKRS_SITE = $(call github,darktohka,knock-rs,master)
KNOCKRS_LICENSE = Apache-2.0
KNOCKRS_LICENSE_FILES = LICENSE

$(eval $(cargo-package))
