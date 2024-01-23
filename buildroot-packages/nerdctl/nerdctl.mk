################################################################################
#
# nerdctl
#
################################################################################

NERDCTL_VERSION = main
NERDCTL_SITE = $(call github,containerd,nerdctl,main)

NERDCTL_LICENSE = Apache-2.0
NERDCTL_LICENSE_FILES = LICENSE

NERDCTL_GOMOD = github.com/containerd/nerdctl/v2

NERDCTL_BUILD_TARGETS = cmd/nerdctl
NERDCTL_INSTALL_BINS = nerdctl

$(eval $(golang-package))
