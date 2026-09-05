.PHONY: build run

IMAGE := ghcr.io/spoletum/toolbox-herdr-pi:v0.0.1 

build:
	podman buildx build --tag $(IMAGE) .

run:
	podman run -ti --name toolbox-herdr-pi $(IMAGE)
