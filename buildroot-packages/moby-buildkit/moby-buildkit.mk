################################################################################
#
# moby-buildkit
#
################################################################################

MOBY_BUILDKIT_VERSION = master
MOBY_BUILDKIT_SITE = $(call github,moby,buildkit,master)
MOBY_BUILDKIT_LICENSE = Apache-2.0
MOBY_BUILDKIT_LICENSE_FILES = LICENSE

MOBY_BUILDKIT_GOMOD = github.com/moby/buildkit

MOBY_BUILDKIT_TAGS = cgo
MOBY_BUILDKIT_BUILD_TARGETS = cmd/buildkitd cmd/buildctl

MOBY_BUILDKIT_INSTALL_BINS = $(notdir $(MOBY_BUILDKIT_BUILD_TARGETS))

$(eval $(golang-package))
