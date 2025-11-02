# Dockerfile for building GCC 4.9.4-VLE on Ubuntu 24.04
# 
# Builds GCC and produces both .deb and .tar.bz2 artifacts
#
# Build the image:
#   docker build -t gcc-4.9.4-vle-builder .
#
# Run the build:
#   docker run --rm -v $(pwd):/workspace gcc-4.9.4-vle-builder
#
# Design: Maximized layer caching for development speed.
# Each package/group is in its own RUN step so adding a new package
# only invalidates that layer and subsequent layers, not the entire build.

FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update package lists (cached unless Ubuntu base image changes)
RUN apt-get update

# Base compression and archive utilities (rarely change)
RUN apt-get install -y --no-install-recommends \
    gzip

RUN apt-get install -y --no-install-recommends \
    bzip2

RUN apt-get install -y --no-install-recommends \
    tar

RUN apt-get install -y --no-install-recommends \
    file

# Core build tools (install separately for better caching)
RUN apt-get install -y --no-install-recommends \
    build-essential

RUN apt-get install -y --no-install-recommends \
    gcc

RUN apt-get install -y --no-install-recommends \
    g++

RUN apt-get install -y --no-install-recommends \
    make

RUN apt-get install -y --no-install-recommends \
    binutils

# Math library dependencies for GCC (install individually for granular caching)
RUN apt-get install -y --no-install-recommends \
    libgmp-dev

RUN apt-get install -y --no-install-recommends \
    libmpfr-dev

RUN apt-get install -y --no-install-recommends \
    libmpc-dev

RUN apt-get install -y --no-install-recommends \
    libisl-dev

# Compression library
RUN apt-get install -y --no-install-recommends \
    zlib1g-dev

# System C library development headers
RUN apt-get install -y --no-install-recommends \
    libc6-dev

# Scripting and text processing tools
RUN apt-get install -y --no-install-recommends \
    gawk

RUN apt-get install -y --no-install-recommends \
    perl

# Multilib support for cross-compilation
RUN apt-get install -y --no-install-recommends \
    gcc-multilib

RUN apt-get install -y --no-install-recommends \
    g++-multilib

# Packaging tools for .deb creation
RUN apt-get install -y --no-install-recommends \
    checkinstall

RUN apt-get install -y --no-install-recommends \
    dpkg-dev

RUN apt-get install -y --no-install-recommends \
    fakeroot

# Clean up package lists (final step, can be invalidated without rebuilding packages)
RUN rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy build script (changes often, so this invalidates minimal layers)
COPY docker-build-and-package.sh /build/build-and-package.sh

RUN chmod +x /build/build-and-package.sh

# Set environment for build
ENV CC=gcc
ENV CXX=g++

# Default command: build and package
CMD ["/build/build-and-package.sh"]
