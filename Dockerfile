# Dockerfile for building GCC 4.9.4-VLE on Ubuntu 24.04
# 
# Build the image:
#   docker build -t gcc-4.9.4-vle-builder .
#
# Run the build:
#   docker run --rm -v $(pwd):/workspace gcc-4.9.4-vle-builder
#
# Or to interactively build:
#   docker run --rm -it -v $(pwd):/workspace gcc-4.9.4-vle-builder bash

FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install all build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    g++ \
    make \
    binutils \
    gcc \
    gzip \
    bzip2 \
    tar \
    file \
    libgmp-dev \
    libmpfr-dev \
    libmpc-dev \
    libisl-dev \
    gawk \
    perl \
    flex \
    bison \
    zlib1g-dev \
    libc6-dev \
    checkinstall \
    dpkg-dev \
    fakeroot \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy build script (changes often, so this invalidates minimal layers)
COPY build-and-package.sh /build/build-and-package.sh

RUN chmod +x /build/build-and-package.sh

# Set environment for build
ENV CC=gcc
ENV CXX=g++

# Default command: build and package
CMD ["/build/build-and-package.sh"]

