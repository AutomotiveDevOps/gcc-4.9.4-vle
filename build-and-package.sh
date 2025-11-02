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

# Create directories
mkdir -p ${BUILD_DIR}
mkdir -p ${OUTPUT_DIR}
mkdir -p ${PREFIX}

# Configure
echo "Configuring GCC..."
cd ${BUILD_DIR}
${SOURCE_DIR}/configure \
    --prefix=${PREFIX} \
    --enable-languages=c,c++ \
    --enable-threads=posix \
    --disable-bootstrap \
    --disable-libsanitizer

# Build
echo "Building GCC (this may take several hours)..."
# Set FLEXFLAGS for compatibility with newer flex versions
export FLEXFLAGS="--nounistd"
make -j$(nproc) FLEXFLAGS="--nounistd"

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

