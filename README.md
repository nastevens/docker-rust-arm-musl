Dockerized Rust for Building ARM MUSL
=====================================

This repo contains a single Dockerfile for building an image capable of
cross-compiling for ARM targets using musl libc. The final container includes
rustc + standard libraries and cargo.


Building
--------

Standard Docker build applies:

    docker build --tag arm-musl-rust .

Start the build and go enjoy a quality 8 hours of sleep.


Running
-------

To use the container, change to the root directory of the Rust code you want to
build. Then execute:

    docker run -v $(pwd):/source --rm -it arm-musl-rust

From there, the usual Rust cross-compiling rules apply. The following targets
are available:

    arm-unknown-linux-musleabi
    arm-unknown-linux-musleabihf
    armv7-unknown-linux-musleabihf

GCC cross compilers for the architectures are in `/usr/local` and are named:

    arm-linux-musleabi-gcc
    arm-linux-musleabihf-gcc
    armv7-linux-musleabihf-gcc


License
-------

This software is distributed under the terms of both the MIT license and/or the
Apache License (Version 2.0), at your option. This code derives significant
functionality from the [rust-buildbot code](https://github.com/rust-lang/rust-buildbot),
which is also Apache/MIT licensed.

See [LICENSE-APACHE](LICENSE-APACHE), [LICENSE-MIT](LICENSE-MIT) for details.
