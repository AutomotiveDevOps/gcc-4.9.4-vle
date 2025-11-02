#!/bin/bash
# Interactive build script for GCC 4.9.4-VLE using Docker

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="gcc-4.9.4-vle-builder"
BUILD_DIR="${SCRIPT_DIR}/../gcc-build"

echo "Starting interactive Docker container for GCC 4.9.4-VLE build..."

# Build Docker image if it doesn't exist
if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
    echo "Building Docker image..."
    docker build -t "${IMAGE_NAME}" "${SCRIPT_DIR}"
fi

# Create build directory
mkdir -p "${BUILD_DIR}"

# Run interactive container
docker run --rm -it \
    -v "${SCRIPT_DIR}:/src/gcc-4.9.4-vle:ro" \
    -v "${BUILD_DIR}:/build/gcc-build" \
    -e CC=gcc \
    -e CXX=g++ \
    "${IMAGE_NAME}" \
    bash

