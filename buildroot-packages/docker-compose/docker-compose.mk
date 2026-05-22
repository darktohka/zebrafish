################################################################################
#
# docker-compose
#
################################################################################

DOCKER_COMPOSE_VERSION = main
DOCKER_COMPOSE_SITE = $(call github,docker,compose,main)
DOCKER_COMPOSE_LICENSE = Apache-2.0
DOCKER_COMPOSE_LICENSE_FILES = LICENSE

DOCKER_COMPOSE_BUILD_TARGETS = cmd
DOCKER_COMPOSE_GOMOD = github.com/docker/compose/v5
DOCKER_COMPOSE_LDFLAGS = \
	-X github.com/docker/compose/v5/internal.Version=$(DOCKER_COMPOSE_VERSION)

define DOCKER_COMPOSE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 $(@D)/bin/cmd \
		$(TARGET_DIR)/usr/lib/docker/cli-plugins/docker-compose
endef

# Some vendored grpc code references http2.TrailerPrefix which was
# removed in newer golang.org/x/net. Replace it with the literal "Trailer:".
define DOCKER_COMPOSE_FIX_TRAILER_PREFIX
	cd $(@D) && \
	find vendor -name '*.go' -exec \
		sed -i 's/http2\.TrailerPrefix/"Trailer:"/g' {} +
endef
DOCKER_COMPOSE_POST_EXTRACT_HOOKS += DOCKER_COMPOSE_FIX_TRAILER_PREFIX

$(eval $(golang-package))
