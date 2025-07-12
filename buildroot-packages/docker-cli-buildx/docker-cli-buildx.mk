################################################################################
#
# docker-cli-buildx
#
################################################################################

DOCKER_CLI_BUILDX_VERSION = origin/master
DOCKER_CLI_BUILDX_SITE = $(call github,docker,buildx,master)

DOCKER_CLI_BUILDX_LICENSE = Apache-2.0
DOCKER_CLI_BUILDX_LICENSE_FILES = LICENSE

DOCKER_CLI_BUILDX_DEPENDENCIES = host-pkgconf

DOCKER_CLI_BUILDX_BUILD_TARGETS = cmd/buildx
DOCKER_CLI_BUILDX_GOMOD = github.com/docker/buildx

DOCKER_CLI_BUILDX_LDFLAGS = \
	-X $(DOCKER_CLI_BUILDX_GOMOD)/version.Revision=master \
	-X $(DOCKER_CLI_BUILDX_GOMOD)/version.Version=master

define DOCKER_CLI_BUILDX_INSTALL_TARGET_CMDS
	$(INSTALL) -m 0755 -D $(@D)/bin/buildx \
		$(TARGET_DIR)/usr/lib/docker/cli-plugins/docker-buildx
endef

$(eval $(golang-package))
