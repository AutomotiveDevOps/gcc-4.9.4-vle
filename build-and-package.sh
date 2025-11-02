#!/bin/bash
set -e

# Configuration - can be overridden by environment variables
SOURCE_DIR=${SOURCE_DIR:-/src/gcc-4.9.4-vle}
BUILD_DIR=${BUILD_DIR:-/build/gcc-build}
PREFIX=${PREFIX:-/usr/local/gcc-4.9.4-vle}
OUTPUT_DIR=${OUTPUT_DIR:-/workspace/output}
VERSION=${GCC_VERSION:-4.9.4}
RELEASE=${GCC_RELEASE:-1}

echo "=== Building GCC ${VERSION}-VLE ==="
# Note: libsanitizer is disabled due to compatibility issues with modern Linux
# kernel headers (Ubuntu 24.04+). The sanitizers are optional and not required
# for the compiler to function. If sanitizer support is needed, it can be
# built separately with modern toolchains.
# Note: multilib is disabled to avoid symlink race conditions in parallel builds
# on modern systems. If 32-bit support is needed, it can be enabled but may
# require sequential builds or additional fixes.

# Create directories
mkdir -p ${BUILD_DIR}
mkdir -p ${OUTPUT_DIR}
mkdir -p ${PREFIX}

# Clean and Configure
echo "Cleaning build directory..."
cd ${BUILD_DIR}
# Force complete cleanup - remove everything to ensure fresh configure
echo "Removing old build configuration and artifacts..."
# Aggressively clean everything including subdirectories
find . -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
rm -rf .[!.]* 2>/dev/null || true  # Remove hidden files too
# Also clean any libsanitizer subdirectories that might have cached objects
rm -rf x86_64-unknown-linux-gnu/libsanitizer 2>/dev/null || true

echo "Configuring GCC..."
${SOURCE_DIR}/configure \
    --prefix=${PREFIX} \
    --enable-languages=c,c++ \
    --enable-threads=posix \
    --disable-bootstrap \
    --disable-libsanitizer \
    --disable-multilib || {
    echo "Configure failed, continuing anyway..."
}

# After configure, ensure gthr-default.h exists in libgcc build directories
echo "Ensuring gthr-default.h exists in all libgcc build directories..."
find ${BUILD_DIR} -type d -name "libgcc" -o -type d -path "*/32/libgcc" -o -type d -path "*/x86_64-*/libgcc" | while read libgcc_dir; do
    if [ -d "$libgcc_dir" ] && [ -f "${SOURCE_DIR}/libgcc/gthr-posix.h" ] && [ ! -f "$libgcc_dir/gthr-default.h" ]; then
        echo "Creating gthr-default.h in $libgcc_dir"
        cp -f "${SOURCE_DIR}/libgcc/gthr-posix.h" "$libgcc_dir/gthr-default.h" || \
        ln -sf "${SOURCE_DIR}/libgcc/gthr-posix.h" "$libgcc_dir/gthr-default.h" || true
    fi
done

# Build
echo "Building GCC (this may take several hours)..."
# Set FLEXFLAGS for compatibility with newer flex versions
export FLEXFLAGS="--nounistd"
# Build with a hook to create gthr-default.h as directories are created
# Use a wrapper that monitors and creates the file during build
echo "Starting build (will create gthr-default.h files as needed)..."
make -j$(nproc) FLEXFLAGS="--nounistd" 2>&1 | tee /tmp/build.log &
MAKE_PID=$!

# Monitor and create gthr-default.h in any new libgcc directories
while kill -0 $MAKE_PID 2>/dev/null; do
    find ${BUILD_DIR} -type d -path "*/libgcc" -exec sh -c '[ -d "$1" ] && [ -f "${SOURCE_DIR}/libgcc/gthr-posix.h" ] && [ ! -f "$1/gthr-default.h" ] && cp -f "${SOURCE_DIR}/libgcc/gthr-posix.h" "$1/gthr-default.h" 2>/dev/null' _ {} \; 2>/dev/null || true
    sleep 1
done

wait $MAKE_PID
BUILD_STATUS=$?

if [ $BUILD_STATUS -ne 0 ]; then
    # If build failed, check if it was due to gthr-default.h and try one more time
    find ${BUILD_DIR} -type d -path "*/libgcc" -exec sh -c '[ -d "$1" ] && [ -f "${SOURCE_DIR}/libgcc/gthr-posix.h" ] && cp -f "${SOURCE_DIR}/libgcc/gthr-posix.h" "$1/gthr-default.h" 2>/dev/null' _ {} \; 2>/dev/null || true
    echo "Retrying build after ensuring all gthr-default.h files exist..."
    make -j$(nproc) FLEXFLAGS="--nounistd"
fi

# Install to staging directory
echo "Installing GCC to staging directory..."
DESTDIR=/tmp/gcc-install make install

# Create .tar.bz2 archive
echo "Creating .tar.bz2 archive..."
cd /tmp
tar -cjf ${OUTPUT_DIR}/gcc-${VERSION}-vle-$(uname -m).tar.bz2 \
    --transform "s,^gcc-install/,gcc-${VERSION}-vle/," \
    gcc-install/

# Create .deb package
echo "Creating .deb package..."

# Try to use checkinstall, but fall back to manual .deb creation
cd /tmp

# Use checkinstall to create .deb (may fail, so we have a fallback)
if checkinstall \
    --type=debian \
    --install=no \
    --pkgname=gcc-4.9.4-vle \
    --pkgversion=${VERSION} \
    --pkgrelease=${RELEASE} \
    --pkglicense=GPL \
    --maintainer="GCC Build <gcc-build@localhost>" \
    --provides=gcc-4.9.4-vle \
    --requires="libc6,libgcc1,libstdc++6" \
    --nodoc \
    --fstrans=yes \
    --pakdir=${OUTPUT_DIR} \
    -D bash -c "cd ${BUILD_DIR} && make install DESTDIR=/tmp/gcc-install" 2>/dev/null; then
    echo "Created .deb using checkinstall"
else
    echo "Using manual .deb creation method..."
    mkdir -p /tmp/deb-package/DEBIAN
    mkdir -p /tmp/deb-package/${PREFIX}
    
    # Copy installed files
    cp -a /tmp/gcc-install/${PREFIX}/* /tmp/deb-package/${PREFIX}/
    
    # Create control file
    ARCH=$(dpkg --print-architecture)
    cat > /tmp/deb-package/DEBIAN/control <<CONTROL
Package: gcc-4.9.4-vle
Version: ${VERSION}-${RELEASE}
Section: devel
Priority: optional
Architecture: ${ARCH}
Depends: libc6 (>= 2.17), libgcc1 (>= 1:4.1.1), libstdc++6 (>= 4.1.1)
Maintainer: GCC Build <gcc-build@localhost>
Description: GCC 4.9.4 with VLE support
 The GNU Compiler Collection version 4.9.4 with Variable Length Encoding support.
CONTROL
    
    # Build .deb
    dpkg-deb --build /tmp/deb-package ${OUTPUT_DIR}/gcc-${VERSION}-vle_${RELEASE}_${ARCH}.deb
fi

echo ""
echo "=== Build Complete ==="
echo "Artifacts created in ${OUTPUT_DIR}:"
ls -lh ${OUTPUT_DIR}/

