ARG GO_IMAGE=golang:1.19
ARG BASE_IMAGE=ubuntu:22.04

FROM ${BASE_IMAGE} as base

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  git \
  && rm -rf /var/lib/apt/lists/*

###############################################################################
FROM base as ffmpeg_builder

ARG FFMPEG_VERSION=6.0

RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  curl \
  wget \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /tools/

# Download, build, and install FFMPEG with iGPU support
RUN wget https://www.ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz \
  && tar -xJf ffmpeg-$FFMPEG_VERSION.tar.xz \
  && cd ffmpeg-$FFMPEG_VERSION \
  && ./configure --enable-nonfree --enable-gpl --enable-libx264 --enable-libx265 --enable-vaapi \
  && make -j$(nproc) \
  && make install

###############################################################################
FROM ${GO_IMAGE} as bench_builder

WORKDIR /app/

# clone in benchmark and checkout highest tagged version
RUN git clone https://github.com/igpu-bench/ibench.git bench/ \
  && cd bench \
  && git checkout $(git tag | grep -Pe "v\d+\.\d+\.\d+" | sort -rh | head -n 1) \
  && go install

###############################################################################
FROM bench_builder as dyn
# Final image with the ability to switch benchmark versions

WORKDIR /app/
COPY ./docker-entrypoint_dyn.sh ./docker-entrypoint.sh

# where downloaded sample media files are stored
ENV IB_SAMPLES_DIR="/samples/"
VOLUME [ "$IB_SAMPLES_DIR" ]

# where temporary transcoding output files are stored
ENV IB_TRANSCODE_DIR="/transcode/"
VOLUME [ "$IB_TRANSCODE_DIR" ]

# where detailed result files are stored
ENV IB_RESULTS_DIR="/results/"
VOLUME [ "$IB_RESULTS_DIR" ]

ENTRYPOINT [ "./docker-entrypoint.sh" ]
CMD ["run"]

###############################################################################
# Final image with a latest-at-build-time benchmark version
FROM base as prod

WORKDIR /app/
COPY ./docker-entrypoint.sh ./docker-entrypoint.sh

COPY --from=bench_builder /go/bin/ibench /usr/bin/ibench

# where downloaded sample media files are stored
ENV IB_SAMPLES_DIR="/samples/"
VOLUME [ "$IB_SAMPLES_DIR" ]

# where temporary transcoding output files are stored
ENV IB_TRANSCODE_DIR="/transcode/"
VOLUME [ "$IB_TRANSCODE_DIR" ]

# where detailed result files are stored
ENV IB_RESULTS_DIR="/results/"
VOLUME [ "$IB_RESULTS_DIR" ]

ENTRYPOINT [ "./docker-entrypoint.sh" ]
CMD ["run"]
