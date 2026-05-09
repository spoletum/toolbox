.PHONY: nvchad

UBUNTU_TAG ?= 24.04

nvchad:
	podman build -f Dockerfile --build-arg UBUNTU_TAG=$(UBUNTU_TAG) --no-cache --tag ghcr.io/spoletum/toolbox-development:nvchad-latest .
