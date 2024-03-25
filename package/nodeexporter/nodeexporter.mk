################################################################################
#
# nodeexporter
#
################################################################################

NODEEXPORTER_VERSION = main
NODEEXPORTER_SITE = $(call github,prometheus,node_exporter,master)
NODEEXPORTER_LICENSE = Apache-2.0
NODEEXPORTER_LICENSE_FILES = LICENSE

NODEEXPORTER_GOMOD = github.com/prometheus/node_exporter

$(eval $(golang-package))
