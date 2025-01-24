################################################################################
#
# dive
#
################################################################################

DIVE_VERSION = main
DIVE_SITE = $(call github,darktohka,dive,zebrafish)
DIVE_LICENSE = MIT
DIVE_LICENSE_FILES = LICENSE

DIVE_GOMOD = github.com/darktohka/dive

define DIVE_REWRITE_SCRIPT
	$(SED) 's/"container-engine", "docker"/"container-engine", "nerdctl"/' $(@D)/cmd/root.go
	$(SED) 's/"source", "docker"/"source", "nerdctl"/' $(@D)/cmd/root.go
endef

DIVE_POST_PATCH_HOOKS += DIVE_REWRITE_SCRIPT

$(eval $(golang-package))
