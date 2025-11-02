#!/bin/bash
# Build script for GCC 4.9.4-VLE using Docker

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="gcc-4.9.4-vle-builder"
BUILD_DIR="${SCRIPT_DIR}/../gcc-build"
PREFIX="/usr/local/gcc-4.9.4-vle"

echo "Building GCC 4.9.4-VLE with Docker..."

# Build Docker image if it doesn't exist
if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
    echo "Building Docker image..."
    docker build -t "${IMAGE_NAME}" "${SCRIPT_DIR}"
fi

# Create build directory
mkdir -p "${BUILD_DIR}"

# Run build
echo "Starting GCC build (this may take several hours)..."
docker run --rm \
    -v "${SCRIPT_DIR}:/src/gcc-4.9.4-vle:ro" \
    -v "${BUILD_DIR}:/build/gcc-build" \
    -e CC=gcc \
    -e CXX=g++ \
    "${IMAGE_NAME}" \
    bash -c "
        cd /build/gcc-build && \
        /src/gcc-4.9.4-vle/configure \
            --prefix=${PREFIX} \
            --enable-languages=c,c++ \
            --enable-threads=posix \
            --disable-bootstrap && \
        make -j\$(nproc)
    "

echo ""
echo "Build complete! Output is in: ${BUILD_DIR}"
echo ""
echo "To install, run from the build directory:"
echo "  cd ${BUILD_DIR}"
echo "  sudo make install"

