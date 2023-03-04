ARG BASE_IMAGE=ubuntu:22.04
FROM $BASE_IMAGE as base

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  git \
  && rm -rf /var/lib/apt/lists/*

###############################################################################
FROM base as builder

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

# Download, build, and install aria2 for torrent downloading
# TODO https://aria2.github.io/manual/en/html/README.html#how-to-get-source-code

###############################################################################
FROM base as prod

WORKDIR /app/
COPY ./docker-entrypoint.sh ./docker-entrypoint.sh

# # clone in benchmark and checkout highest tagged version
RUN git clone https://github.com/igpu-bench/bench.git bench/ \
  && cd bench \
  && git checkout $(git tag | grep -Pe "v\d+\.\d+\.\d+" | sort -rh | head -n 1)

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
CMD ["run-all"]
