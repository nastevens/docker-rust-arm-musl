FROM ubuntu:16.04

# Almost everything is going to run as rustbuild user, so we need sudo for the
# few things that need to be run as root
RUN apt-get update && \
    apt-get install -y --force-yes --no-install-recommends sudo && \
    rm -rf /var/lib/apt/lists/* 
RUN groupadd -r rustbuild && useradd -m -r -g rustbuild -G sudo rustbuild

COPY configs/arm-linux-musleabi.config \
     configs/arm-linux-musleabihf.config \
     configs/armv7-linux-musleabihf.config \
     fix_musl_target_paths.patch \
     config.toml \
     /build/

USER rustbuild
RUN install.sh

ENV USER=rustbuild \
    PATH=/rust/bin:${PATH} \
    LD_LIBRARY_PATH=/rust/lib:${LD_LIBRARY_PATH}
WORKDIR /source
VOLUME ["/source"]
CMD ["bash", "--login"]
