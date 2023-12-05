################################################################################
#
# moby-buildkit
#
################################################################################

MAINLINEBUILDKIT_VERSION = master
MAINLINEBUILDKIT_SITE = $(call github,moby,buildkit,master)
MAINLINEBUILDKIT_LICENSE = Apache-2.0
MAINLINEBUILDKIT_LICENSE_FILES = LICENSE

MAINLINEBUILDKIT_GOMOD = github.com/moby/buildkit

MAINLINEBUILDKIT_TAGS = cgo
MAINLINEBUILDKIT_BUILD_TARGETS = cmd/buildkitd cmd/buildctl

MAINLINEBUILDKIT_INSTALL_BINS = $(notdir $(MAINLINEBUILDKIT_BUILD_TARGETS))

$(eval $(golang-package))
