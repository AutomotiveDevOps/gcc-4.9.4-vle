#!/bin/bash
# Build script for GCC 4.9.4-VLE using Docker
# Builds GCC and creates .deb and .tar.bz2 artifacts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="gcc-4.9.4-vle-builder"
OUTPUT_DIR="${SCRIPT_DIR}/output"
BUILD_DIR="${SCRIPT_DIR}/../gcc-build"

echo "Building GCC 4.9.4-VLE with Docker..."
echo "Artifacts will be saved to: ${OUTPUT_DIR}"

# Build Docker image if it doesn't exist
if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
    echo "Building Docker image..."
    docker build -t "${IMAGE_NAME}" "${SCRIPT_DIR}"
fi

# Create output directory
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${BUILD_DIR}"

# Run build and packaging
echo "Starting GCC build and packaging (this may take several hours)..."
echo "Using all available CPUs ($(nproc))..."
docker run --rm \
    --cpus=$(nproc) \
    -v "${SCRIPT_DIR}:/src/gcc-4.9.4-vle:ro" \
    -v "${BUILD_DIR}:/build/gcc-build" \
    -v "${OUTPUT_DIR}:/workspace/output" \
    "${IMAGE_NAME}"

echo ""
echo "=== Build Complete ==="
echo "Artifacts created in: ${OUTPUT_DIR}"
if [ -d "${OUTPUT_DIR}" ]; then
    ls -lh "${OUTPUT_DIR}"/
fi

