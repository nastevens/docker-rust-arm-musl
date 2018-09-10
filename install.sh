#!/bin/sh

set -ex

CROSSTOOL_NG_VERSION="1.22.0"
LLVM_VERSION="3.8.0"

install_deps() {
    sudo apt-get update
    sudo apt-get install -y --force-yes --no-install-recommends \
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
        sudo \
        texinfo \
        wget \
        xz-utils \
        zlib1g-dev
}

cleanup_deps() {
    sudo apt-get remove -y --force-yes \
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
        sudo \
        texinfo \
        wget \
        xz-utils \
        zlib1g-dev
    rm -rf /var/lib/apt/lists/*
}

create_rustbuild_owned_dir() {
    local new_dir=$1
    sudo mkdir $new_dir
    sudo chown rustbuild:rustbuild $new_dir
}

install_crosstool_ng() {
    # Build/install crosstool-ng cross compilers
    # NOTE crosstool-ng can't be executed by root so we execute it under the
    # rustbuild user. /x-tools is the crosstool-ng output directory and /build
    # is the crosstool-ng build directory so both must be writable by rustbuild
    create_rustbuild_owned_dir /x-tools
    local uri="http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-${CROSSTOOL_NG_VERSION}.tar.bz2"
    curl $uri | tar xj
    pushd crosstool-ng
    ./configure --prefix=/usr/local
    make
    sudo make install
    popd
    rm -rf crosstool-ng
}

build_toolchain() {
    local target=$1
    mkdir $target
    pushd $target
    cp ../${target}.config .config
    ct-ng oldconfig
    ct-ng build
    popd
    rm -rf $target
}

build_all_toolchains() {
    build_toolchain arm-linux-musleabi
    build_toolchain arm-linux-musleabihf
    build_toolchain armv7-linux-musleabihf
}

get_libunwind_source() {
    if [ ! -d "llvm-${LLVM_VERSION}.src"  ]; then
        curl http://llvm.org/releases/${LLVM_VERSION}/llvm-${LLVM_VERSION}.src.tar.xz | tar xJf -
    fi

    if [ ! -d "libunwind-${LLVM_VERSION}.src" ]; then
        curl http://llvm.org/releases/${LLVM_VERSION}/libunwind-${LLVM_VERSION}.src.tar.xz | tar xJf -
    fi
}

build_libunwind() {
    local target=$1
    mkdir libunwind-build
    pushd libunwind-build
    CC=${target/unknown-/}-gcc CXX=${target/unknown-/}-gcc cmake \
        ../libunwind-${LLVM_VERSION}.src \
        -DLLVM_PATH=../llvm-${LLVM_VERSION}.src \
        -DLIBUNWIND_ENABLE_SHARED=0
    VERBOSE=1 make -j1
    cp lib/libunwind.a /x-tools/${target}/${target}/sysroot/usr/lib/
    popd
    rm -rf libunwind-build
}

build_all_libunwinds() {
    get_libunwind_source
    build_libunwind arm-unknown-linux-musleabi
    build_libunwind arm-unknown-linux-musleabihf
    build_libunwind armv7-unknown-linux-musleabihf
    rm -rf "llvm-${LLVM_VERSION}.src" "libunwind-${LLVM_VERSION}.src"

    # Rename all the compilers we just built into /usr/bin and also without
    # `-unknown-` in the name because it appears lots of other compilers in Ubuntu
    # don't have this name in the component by default either.
    for f in `ls /x-tools/*-unknown-linux-*/bin/*-unknown-linux-*`; do
        g=`basename $f`
        sudo ln -vs $f /usr/bin/$(echo $g | sed -e 's/-unknown//')
    done
}

download_and_patch_rust() {
    curl "https://static.rust-lang.org/dist/rustc-nightly-src.tar.gz" | tar zxf -
    pushd rustc-nightly
    patch -p1 < ../fix_musl_target_paths.patch
    popd
}

build_rust() {
    mkdir rust-build
    pushd rust-build
    export RUST_BACKTRACE=1
    cp /build/config.toml .
    python /build/rustc-nightly/src/bootstrap/bootstrap.py --verbose
    popd
}

install_rust() {
    create_rustbuild_owned_dir /rust
    mv /build/rust-build/build/x86_64-unknown-linux-gnu/stage/* /rust
    rm -rf rust-build
}

install_cargo() {
    curl https://static.rust-lang.org/cargo-dist/cargo-nightly-x86_64-unknown-linux-gnu.tar.gz | tar zxf -
    pushd cargo-nightly-x86_64-unknown-linux-gnu
    ./install --prefix=/rust
    popd
}

main() {
    install_deps
    sudo chown -R rustbuild:rustbuild /build
    cd /build

    install_crosstool_ng
    build_all_toolchains
    build_all_libunwinds
    download_and_patch_rust
    build_rust
    install_rust
    install_cargo

    rm -rf /build
    cleanup_deps
    create_rustbuild_owned_dir /source
}

dev() {
    sudo chown -R rustbuild:rustbuild /build
    cd /build
    $@
}

dev $@
