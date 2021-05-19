.PHONY: doc build nix-shell build-docker-image
DEFAULT_GOAL: help

IMAGE_NAME=denibertovic/ingres-fail-page

progress=auto

## Build ingress-fail-page with nix
build:
	@nix-build --attr app release.nix $(builders)

## Build docker image for ingress-fail-page with nix
build-docker-image:
	@nix-build --attr app-docker-image release.nix
	@docker load < ./result

## Enter ingress-fail-page nix-shell
nix-shell:
	@nix-shell

## Show help screen.
help:
	@echo "Please use \`make <target>' where <target> is one of\n\n"
	@awk '/^[a-zA-Z\-0-9_]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "%-30s %s\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

