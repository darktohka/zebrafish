################################################################################
#
# docker-cli
#
################################################################################

DOCKER_CLI_VERSION = origin/master
DOCKER_CLI_SITE = $(call github,docker,cli,master)

DOCKER_CLI_DEPENDENCIES = host-pkgconf

DOCKER_CLI_TAGS = autogen
DOCKER_CLI_BUILD_TARGETS = cmd/docker
DOCKER_CLI_GOMOD = github.com/docker/cli

DOCKER_CLI_LDFLAGS = \
	-X $(DOCKER_CLI_GOMOD)/cli/version.GitCommit=master \
	-X $(DOCKER_CLI_GOMOD)/cli/version.Version=master

ifeq ($(BR2_PACKAGE_DOCKER_CLI_STATIC),y)
DOCKER_CLI_LDFLAGS += -extldflags '-static'
DOCKER_CLI_TAGS += osusergo netgo
DOCKER_CLI_GO_ENV = CGO_ENABLED=no
endif

DOCKER_CLI_INSTALL_BINS = $(notdir $(DOCKER_CLI_BUILD_TARGETS))

$(eval $(golang-package))
