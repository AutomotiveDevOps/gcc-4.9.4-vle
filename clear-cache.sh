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

# Remove build directory
echo "Removing build directory..."
rm -rf ../gcc-build

# Remove any Docker volumes related to the build (if any)
echo "Pruning unused Docker volumes..."
docker volume prune -f

echo ""
echo "=== Cache cleared! ==="
echo "Next build will start fresh."

