ARG GO_IMAGE=golang:1.19-bullseye
ARG BASE_IMAGE=debian:bullseye

FROM ${BASE_IMAGE} as base

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  git \
  libx264-.* \
  libx265-.* \
  libva2 libdrm-common libdrm2 libva-drm2 \
  && rm -rf /var/lib/apt/lists/*

###############################################################################
FROM ${GO_IMAGE} as go-base

RUN apt-get update && apt-get install -y --no-install-recommends \
  libx264-.* \
  libx265-.* \
  libva2 libdrm-common libdrm2 libva-drm2 \
  && rm -rf /var/lib/apt/lists/*

###############################################################################
FROM base as ffmpeg_builder

ARG FFMPEG_VERSION=6.0
ARG VMAF_VERSION=2.3.1
ARG OUT_PATH=/tools

RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  libva-dev \
  libvpx-dev \
  libx264-dev \
  libx265-dev libnuma-dev \
  meson \
  ninja-build \
  pkg-config \
  wget \
  yasm nasm \
  && mkdir -p ${OUT_PATH}/lib/pkgconfig

WORKDIR /builder/
ENV PKG_CONFIG_PATH="${OUT_PATH}/lib/pkgconfig:$PKG_CONFIG_PATH"

# Download, build, and install VMAF
RUN wget https://github.com/Netflix/vmaf/archive/v${VMAF_VERSION}.tar.gz \
  && tar xf v${VMAF_VERSION}.tar.gz \
  && rm v${VMAF_VERSION}.tar.gz \
  && mkdir -p vmaf-${VMAF_VERSION}/libvmaf/build \
  && cd vmaf-${VMAF_VERSION}/libvmaf/build \
  && meson setup -Denable_tests=false -Denable_docs=false --buildtype=release --default-library=static .. --prefix=${OUT_PATH} --bindir=${OUT_PATH}/bin/ --libdir=${OUT_PATH}/lib/ \
  && ninja \
  && ninja install

# Download, build, and install FFMPEG with iGPU support
RUN wget https://www.ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz \
  && tar -xJf ffmpeg-${FFMPEG_VERSION}.tar.xz \
  && rm ffmpeg-${FFMPEG_VERSION}.tar.xz \
  && cd ffmpeg-${FFMPEG_VERSION} \
  && ./configure \
  --prefix="${OUT_PATH}/" \
  --bindir="${OUT_PATH}/bin" \
  --pkg-config-flags="--static" \
  --extra-ldflags="-L${OUT_PATH}/lib" \
  --extra-cflags="-I${OUT_PATH}/include" \
  --ld="g++" \
  --enable-nonfree \
  --enable-gpl \
  --enable-version3 \
  --enable-libx264 \
  --enable-libx265 \
  --enable-vaapi \
  --enable-libvmaf \
  --disable-ffplay \
  --disable-doc \
  && make -j$(nproc) \
  && make install

###############################################################################
FROM go-base as bench_builder

WORKDIR /app/

# clone in benchmark and checkout highest tagged version
RUN git clone https://github.com/igpu-bench/ibench.git bench/ \
  && cd bench \
  && git checkout $(git tag | grep -Pe "v\d+\.\d+\.\d+" | sort -rh | head -n 1) \
  && go install

###############################################################################
# Final image with the ability to switch benchmark versions
FROM bench_builder as dyn

COPY --from=ffmpeg_builder /tools/bin/* /bin/
COPY --from=ffmpeg_builder /tools/lib/* /lib/

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

COPY --from=ffmpeg_builder /tools/bin/* /bin/
COPY --from=ffmpeg_builder /tools/lib/* /lib/

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
