.PHONY: nvchad nvchad-amd64 nvchad-arm64

UBUNTU_TAG ?= 24.04
PLATFORM ?= linux/amd64

nvchad:
	podman build --platform $(PLATFORM) -f Dockerfile --build-arg UBUNTU_TAG=$(UBUNTU_TAG) --no-cache --tag ghcr.io/spoletum/toolbox-development:nvchad-latest .

nvchad-amd64:
	$(MAKE) nvchad PLATFORM=linux/amd64

nvchad-arm64:
	$(MAKE) nvchad PLATFORM=linux/arm64
