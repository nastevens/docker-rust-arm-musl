FROM ubuntu:16.04

# Almost everything is going to run as rustbuild user, so we need sudo for the
# few things that need to be run as root
RUN apt-get update && \
    apt-get install -y --force-yes --no-install-recommends sudo && \
    rm -rf /var/lib/apt/lists/* 
RUN groupadd -r rustbuild && useradd -m -r -g rustbuild -G sudo rustbuild
RUN echo 'rustbuild ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/rustbuild

COPY configs/arm-linux-musleabi.config \
     configs/arm-linux-musleabihf.config \
     configs/armv7-linux-musleabihf.config \
     fix_musl_target_paths.patch \
     config.toml \
     install.sh \
     /build/

USER rustbuild
RUN bash /build/install.sh install_deps
RUN bash /build/install.sh install_crosstool_ng
RUN bash /build/install.sh build_all_toolchains
RUN bash /build/install.sh build_all_libunwinds
RUN bash /build/install.sh download_and_patch_rust
RUN bash /build/install.sh build_rust
RUN bash /build/install.sh install_rust
RUN bash /build/install.sh install_cargo
RUN bash /build/install.sh cleanup_deps

ENV USER=rustbuild \
    PATH=/rust/bin:${PATH} \
    LD_LIBRARY_PATH=/rust/lib:${LD_LIBRARY_PATH}
WORKDIR /source
VOLUME ["/source"]
CMD ["bash", "--login"]
