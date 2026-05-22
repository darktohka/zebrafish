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

NERDCTL_LDFLAGS = \
	-X $(NERDCTL_GOMOD)/pkg/version.Version=$(NERDCTL_VERSION)

NERDCTL_BUILD_TARGETS = cmd/nerdctl

# Some vendored grpc code references http2.TrailerPrefix which was
# removed in newer golang.org/x/net. Replace it with the literal "Trailer:".
define NERDCTL_FIX_TRAILER_PREFIX
	cd $(@D) && \
	find vendor -name '*.go' -exec \
		sed -i 's/http2\.TrailerPrefix/"Trailer:"/g' {} +
endef
NERDCTL_POST_EXTRACT_HOOKS += NERDCTL_FIX_TRAILER_PREFIX

$(eval $(golang-package))
