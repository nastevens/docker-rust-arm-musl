FROM ubuntu:16.04

RUN apt-get update
RUN apt-get install -y --force-yes --no-install-recommends \
        automake \
        bison \
        bsdtar \
        bzip2 \
        ca-certificates \
        cmake \
        curl \
        file \
        flex \
        g++ \
        gawk \
        git \
        gperf \
        help2man \
        libc6-dev \
        libncurses-dev \
        libtool-bin \
        make \
        ninja-build \
        patch \
        python-dev \
        texinfo \
        wget \
        xz-utils \
        zlib1g-dev

# Add rustbuild user
RUN groupadd -r rustbuild && useradd -m -r -g rustbuild rustbuild

# Build/install crosstool-ng cross compilers
# NOTE crosstool-ng can't be executed by root so we execute it under the
# rustbuild user. /x-tools is the crosstool-ng output directory and /build is
# the crosstool-ng build directory so both must be writable by rustbuild
RUN mkdir /x-tools && \
    chown rustbuild:rustbuild /x-tools && \
    mkdir /build && \
    chown rustbuild:rustbuild /build
WORKDIR /build
RUN curl http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-1.22.0.tar.bz2 | tar xj
RUN cd crosstool-ng && ./configure --prefix=/usr/local && make && make install && cd - && rm -rf crosstool-ng
COPY scripts/build_toolchain.sh \
    configs/arm-linux-musleabi.config \
    configs/arm-linux-musleabihf.config \
    configs/armv7-linux-musleabihf.config \
    /build/

# Build MUSL toolchain targets
USER rustbuild
RUN /bin/bash build_toolchain.sh arm-linux-musleabi
RUN /bin/bash build_toolchain.sh arm-linux-musleabihf
RUN /bin/bash build_toolchain.sh armv7-linux-musleabihf

USER root

# Rename all the compilers we just built into /usr/bin and also without
# `-unknown-` in the name because it appears lots of other compilers in Ubuntu
# don't have this name in the component by default either.
RUN                                                                           \
  for f in `ls /x-tools/*-unknown-linux-*/bin/*-unknown-linux-*`; do          \
    g=`basename $f`;                                                          \
    ln -vs $f /usr/bin/`echo $g | sed -e 's/-unknown//'`;                     \
  done

# Build libunwind.a for the ARM MUSL targets
COPY scripts/build-libunwind.sh /build/
RUN /bin/bash build-libunwind.sh arm-unknown-linux-musleabi
RUN /bin/bash build-libunwind.sh arm-unknown-linux-musleabihf
RUN /bin/bash build-libunwind.sh armv7-unknown-linux-musleabihf

# Instruct rustbuild to use the armv7-linux-gnueabihf toolchain instead of the
# default arm-linux-gnueabihf one
ENV AR_arm_unknown_linux_musleabi=arm-linux-musleabi-ar \
    CC_arm_unknown_linux_musleabi=arm-linux-musleabi-gcc \
    CXX_arm_unknown_linux_musleabi=arm-linux-musleabi-g++ \
    AR_arm_unknown_linux_musleabihf=arm-linux-musleabihf-ar \
    CC_arm_unknown_linux_musleabihf=arm-linux-musleabihf-gcc \
    CXX_arm_unknown_linux_musleabihf=arm-linux-musleabihf-g++ \
    AR_armv7_unknown_linux_musleabihf=armv7-linux-musleabihf-ar \
    CC_armv7_unknown_linux_musleabihf=armv7-linux-musleabihf-gcc \
    CXX_armv7_unknown_linux_musleabihf=armv7-linux-musleabihf-g++

# Clone the latest Rust
RUN mkdir /rust && \
    chown rustbuild:rustbuild /rust && \
    mkdir /build/rust && \
    chown rustbuild:rustbuild /build/rust
USER rustbuild
RUN git clone https://github.com/rust-lang/rust.git /rust
COPY fix_musl_target_paths.patch /build/fix_musl_target_paths.patch
RUN git -C /rust apply /build/fix_musl_target_paths.patch

ENV RUST_BACKTRACE=1
WORKDIR /build/rust
COPY config.toml /build/rust/
RUN python /rust/src/bootstrap/bootstrap.py \
    --verbose \
    --config /build/rust/config.toml

# Install rustup and link to our toolchain
USER root
RUN mkdir /build/rustup && \
    chown rustbuild:rustbuild /build/rustup
USER rustbuild
WORKDIR /build/rustup
RUN wget https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init && \
    chmod +x rustup-init && \
    ./rustup-init -y --default-toolchain nightly

# We have to manually source cargo/env b/c we're running with sh, which
# doesn't pick up changes in .profile because we're not a login shell
RUN . ~/.cargo/env && rustup toolchain link arm-musl-rust /build/rust/build/x86_64-unknown-linux-gnu/stage2/
RUN . ~/.cargo/env && rustup default arm-musl-rust

USER root
RUN mkdir /source && \
    chown rustbuild:rustbuild /source

USER rustbuild
ENV USER=rustbuild
WORKDIR /source
VOLUME ["/source"]
CMD ["bash", "--login"]
