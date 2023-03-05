
DOCKER_NAME_BASE=ghcr.io/igpu-bench/igpu-bench

build: build-prod

build-prod:
	docker build -t $(DOCKER_NAME_BASE):prod --target prod -f Dockerfile .

build-dyn:
	docker build -t $(DOCKER_NAME_BASE):dyn --target dyn -f Dockerfile .

build-ffmpeg:
	docker build -t $(DOCKER_NAME_BASE):ffmpeg --target ffmpeg_builder -f Dockerfile .

debug: build-prod
	docker run --rm -it $(DOCKER_NAME_BASE):prod bash

debug-dyn: build-dyn
	docker run --rm -it $(DOCKER_NAME_BASE):dyn bash

debug-ffmpeg: build-ffmpeg
	docker run --rm -it $(DOCKER_NAME_BASE):ffmpeg bash

clean:
	docker image rm $(DOCKER_NAME_BASE):prod $(DOCKER_NAME_BASE):dyn $(DOCKER_NAME_BASE):ffmpeg
