################################################################################
#
# zfsexporter
#
################################################################################

ZFSEXPORTER_VERSION = main
ZFSEXPORTER_SITE = $(call github,pdf,zfs_exporter,master)
ZFSEXPORTER_LICENSE =o MIT
ZFSEXPORTER_LICENSE_FILES = LICENSE

ZFSEXPORTER_GOMOD = github.com/pdf/zfs_exporter/v2

$(eval $(golang-package))
