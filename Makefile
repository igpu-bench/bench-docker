
DOCKER_NAME_BASE=ghcr.io/igpu-bench/igpu-bench

build:
	docker build -t $(DOCKER_NAME_BASE):debug -f Dockerfile .

debug: build
	docker run --rm -it $(DOCKER_NAME_BASE):debug bash
