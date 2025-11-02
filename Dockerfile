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
    gcc-multilib \
    g++-multilib \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy source code (will be overridden by volume mount in practice)
COPY . /src/gcc-4.9.4-vle

# Create build directory
RUN mkdir -p /build/gcc-build

# Set environment for build
ENV CC=gcc
ENV CXX=g++

# Default command: configure and build
CMD ["bash", "-c", "cd /build/gcc-build && /src/gcc-4.9.4-vle/configure --prefix=/usr/local/gcc-4.9.4-vle --enable-languages=c,c++ --enable-threads=posix --disable-bootstrap && make -j$(nproc)"]

