################################################################################
#
# go-bootstrap-stage5
#
################################################################################

# Use last Go version that go-bootstrap-stage4 can build: v1.24.x
GO_BOOTSTRAP_STAGE5_VERSION = 1.24.6
GO_BOOTSTRAP_STAGE5_SITE = https://storage.googleapis.com/golang
GO_BOOTSTRAP_STAGE5_SOURCE = go$(GO_BOOTSTRAP_STAGE5_VERSION).src.tar.gz

GO_BOOTSTRAP_STAGE5_LICENSE = BSD-3-Clause
GO_BOOTSTRAP_STAGE5_LICENSE_FILES = LICENSE

# Use go-bootstrap-stage4 to bootstrap.
HOST_GO_BOOTSTRAP_STAGE5_DEPENDENCIES = host-go-bootstrap-stage4

HOST_GO_BOOTSTRAP_STAGE5_ROOT = $(HOST_DIR)/lib/go-$(GO_BOOTSTRAP_STAGE5_VERSION)

# The go build system is not compatible with ccache, so use
# HOSTCC_NOCCACHE.  See https://github.com/golang/go/issues/11685.
HOST_GO_BOOTSTRAP_STAGE5_MAKE_ENV = \
	GO111MODULE=off \
	GOCACHE=$(HOST_GO_HOST_CACHE) \
	GOROOT_BOOTSTRAP=$(HOST_GO_BOOTSTRAP_STAGE4_ROOT) \
	GOROOT_FINAL=$(HOST_GO_BOOTSTRAP_STAGE5_ROOT) \
	GOROOT="$(@D)" \
	GOBIN="$(@D)/bin" \
	GOOS=linux \
	CC=$(HOSTCC_NOCCACHE) \
	CXX=$(HOSTCXX_NOCCACHE) \
	CGO_ENABLED=0

define HOST_GO_BOOTSTRAP_STAGE5_BUILD_CMDS
	cd $(@D)/src && \
		$(HOST_GO_BOOTSTRAP_STAGE5_MAKE_ENV) ./make.bash $(if $(VERBOSE),-v)
endef

define HOST_GO_BOOTSTRAP_STAGE5_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(@D)/bin/go $(HOST_GO_BOOTSTRAP_STAGE5_ROOT)/bin/go
	$(INSTALL) -D -m 0755 $(@D)/bin/gofmt $(HOST_GO_BOOTSTRAP_STAGE5_ROOT)/bin/gofmt

	cp -a $(@D)/lib $(HOST_GO_BOOTSTRAP_STAGE5_ROOT)/

	mkdir -p $(HOST_GO_BOOTSTRAP_STAGE5_ROOT)/pkg
	cp -a $(@D)/pkg/include $(HOST_GO_BOOTSTRAP_STAGE5_ROOT)/pkg/
	cp -a $(@D)/pkg/tool $(HOST_GO_BOOTSTRAP_STAGE5_ROOT)/pkg/

	# The Go sources must be installed to the host/ tree for the Go stdlib.
	cp -a $(@D)/src $(HOST_GO_BOOTSTRAP_STAGE5_ROOT)/
endef

$(eval $(host-generic-package))
