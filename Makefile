# special makefile variables
.DEFAULT_GOAL := help
.RECIPEPREFIX := >

# recursively expanded variables
SHELL = /usr/bin/sh
SOURCES = \
	yq\
	talos

# targets
HELP = help
SETUP = setup
DEBS = debs
CLEAN = clean

# to be (or can be) passed in at make runtime
export VERSION =

# executables
PYTHON = python
PIP = pip
PRE_COMMIT = pre-commit
NPM = npm

# simply expanded variables
executables := \
	${PYTHON}\
	${NPM}

_check_executables := $(foreach exec,${executables},$(if $(shell command -v ${exec}),pass,$(error "No ${exec} in PATH")))

.PHONY: ${HELP}
${HELP}:
	# inspired by the makefiles of the Linux kernel and Mercurial
>	@printf "%s\n" "Common make targets:"
>	@printf "%s\n" "  ${SETUP}                 - install the distro-independent dependencies for this"
>	@printf "%s\n" "                          repository"
>	@printf "%s\n" "  ${DEBS}                  - create the sources' deb packages"
>	@printf "%s\n" "  ${CLEAN}                 - remove files generated from targets"
>	@printf "%s\n" "Common make configurations (e.g. make [config]=1 [targets]):"
>	@printf "%s\n" "  SOURCES               - sets the sources to build packages for"

.PHONY: ${SETUP}
${SETUP}:
>	${NPM} install
>	${PYTHON} -m ${PIP} install --upgrade "${PIP}"
>	${PYTHON} -m ${PIP} install --requirement "./requirements-dev.txt"
>	${PRE_COMMIT} install

%:: scripts/build-pkgs-%
>	./$<

.PHONY: ${DEBS}
${DEBS}: ${SOURCES}

.PHONY: ${CLEAN}
${CLEAN}:
>	@printf "%s\n" "make: nothing to clean"
