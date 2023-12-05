################################################################################
#
# nerdctl
#
################################################################################

MAINLINENERDCTL_VERSION = main
MAINLINENERDCTL_SITE = $(call github,containerd,nerdctl,main)

MAINLINENERDCTL_LICENSE = Apache-2.0
MAINLINENERDCTL_LICENSE_FILES = LICENSE

MAINLINENERDCTL_GOMOD = github.com/containerd/nerdctl

MAINLINENERDCTL_BUILD_TARGETS = cmd/nerdctl
MAINLINENERDCTL_INSTALL_BINS = nerdctl

$(eval $(golang-package))
