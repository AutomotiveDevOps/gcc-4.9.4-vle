#!/bin/bash
# Clear all caches related to GCC build
set -e

echo "=== Clearing GCC build caches ==="

# Stop and remove any running containers
echo "Stopping any running build containers..."
docker ps -q --filter "ancestor=gcc-4.9.4-vle-builder" | xargs -r docker kill 2>/dev/null || true
docker ps -aq --filter "ancestor=gcc-4.9.4-vle-builder" | xargs -r docker rm 2>/dev/null || true

# Remove the Docker image to force rebuild
echo "Removing Docker builder image..."
docker rmi gcc-4.9.4-vle-builder 2>/dev/null || true

# Clear Docker build cache
echo "Clearing Docker build cache..."
docker builder prune -af

# Remove build directory (may be owned by root from Docker)
echo "Removing build directory..."
BUILD_DIR="${SCRIPT_DIR}/../gcc-build"
if [ -d "${BUILD_DIR}" ]; then
    # Try normal removal first
    rm -rf "${BUILD_DIR}" 2>/dev/null || {
        # If that fails due to permissions, use Docker to remove (it created them as root)
        echo "Build directory has root-owned files, using Docker to remove..."
        docker run --rm -v "${BUILD_DIR}:/build-dir:rw" ubuntu:24.04 bash -c "rm -rf /build-dir/* /build-dir/.[!.]* 2>/dev/null; rmdir /build-dir 2>/dev/null || true" || true
        # If directory still exists, at least try to clear it
        if [ -d "${BUILD_DIR}" ]; then
            echo "Note: Build directory ${BUILD_DIR} still exists but contents should be cleared."
            echo "      It will be reused on next build (contents will be overwritten)."
        fi
    }
fi

# Remove any Docker volumes related to the build (if any)
echo "Pruning unused Docker volumes..."
docker volume prune -f

echo ""
echo "=== Cache cleared! ==="
echo "Next build will start fresh."

