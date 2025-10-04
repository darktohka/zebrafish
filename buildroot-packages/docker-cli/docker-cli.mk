################################################################################
#
# docker-cli
#
################################################################################

DOCKER_CLI_VERSION = master
DOCKER_CLI_SITE = $(call github,docker,cli,master)

DOCKER_CLI_LICENSE = Apache-2.0
DOCKER_CLI_LICENSE_FILES = LICENSE

DOCKER_CLI_DEPENDENCIES = host-pkgconf

DOCKER_CLI_CPE_ID_VENDOR = docker
DOCKER_CLI_CPE_ID_PRODUCT = docker

DOCKER_CLI_TAGS = autogen
DOCKER_CLI_BUILD_TARGETS = cmd/docker
DOCKER_CLI_GOMOD = github.com/docker/cli

DOCKER_CLI_LDFLAGS = \
	-X $(DOCKER_CLI_GOMOD)/cli/version.GitCommit=$(DOCKER_CLI_VERSION) \
	-X $(DOCKER_CLI_GOMOD)/cli/version.Version=$(DOCKER_CLI_VERSION)

ifeq ($(BR2_PACKAGE_DOCKER_CLI_STATIC),y)
DOCKER_CLI_LDFLAGS += -extldflags '-static'
DOCKER_CLI_TAGS += osusergo netgo
DOCKER_CLI_GO_ENV = CGO_ENABLED=no
endif

# create the go.mod file with language version go1.19
# remove the conflicting vendor/modules.txt
# https://github.com/moby/moby/issues/44618#issuecomment-1343565705
# define DOCKER_CLI_FIX_VENDORING
# 	printf "module $(DOCKER_CLI_GOMOD)\n\ngo 1.23\n" > $(@D)/go.mod
# 	rm -f $(@D)/vendor/modules.txt
# endef
# DOCKER_CLI_POST_EXTRACT_HOOKS += DOCKER_CLI_FIX_VENDORING

define DOCKER_CLI_FIX_VENDORING
	cd $(@D)
	cp "$(@D)/vendor.mod" "$(@D)/go.mod"
	cp "$(@D)/vendor.sum" "$(@D)/go.sum"
endef
DOCKER_CLI_POST_EXTRACT_HOOKS += DOCKER_CLI_FIX_VENDORING

#DOCKER_CLI_GO_ENV += \
#	GOFLAGS=-mod=mod \
#	GO111MODULE=on \
#	GOPROXY=https://proxy.golang.org,direct \
#	GOSUMDB=sum.golang.org
#
$(eval $(golang-package))
