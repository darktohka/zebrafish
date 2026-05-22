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
MOBY_BUILDKIT_BUILD_TARGETS = cmd/buildctl cmd/buildkitd

MOBY_BUILDKIT_LDFLAGS = \
	-X $(MOBY_BUILDKIT_GOMOD)/version.Version="$(MOBY_BUILDKIT_VERSION)"

HOST_MOBY_BUILDKIT_TAGS = cgo
HOST_MOBY_BUILDKIT_BUILD_TARGETS = cmd/buildctl cmd/buildkitd

# Some vendored grpc code references http2.TrailerPrefix which was
# removed in newer golang.org/x/net. Replace it with the literal "Trailer:".
define MOBY_BUILDKIT_FIX_TRAILER_PREFIX
	cd $(@D) && \
	find vendor -name '*.go' -exec \
		sed -i 's/http2\.TrailerPrefix/"Trailer:"/g' {} +
endef
MOBY_BUILDKIT_POST_EXTRACT_HOOKS += MOBY_BUILDKIT_FIX_TRAILER_PREFIX

$(eval $(golang-package))
$(eval $(host-golang-package))
