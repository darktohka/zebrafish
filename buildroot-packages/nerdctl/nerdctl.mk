################################################################################
#
# nerdctl
#
################################################################################

NERDCTL_VERSION = main
NERDCTL_SITE = $(call github,darktohka,nerdctl,main)

NERDCTL_LICENSE = Apache-2.0
NERDCTL_LICENSE_FILES = LICENSE

NERDCTL_GOMOD = github.com/containerd/nerdctl/v2

NERDCTL_BUILD_TARGETS = cmd/nerdctl
NERDCTL_INSTALL_BINS = nerdctl

define NERDCTL_REMOVE_GO_SUM
	rm -f $(@D)/go.sum
endef

NERDCTL_POST_EXTRACT_HOOKS += NERDCTL_REMOVE_GO_SUM

$(eval $(golang-package))
