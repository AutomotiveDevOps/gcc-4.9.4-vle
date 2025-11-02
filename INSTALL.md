# Installation Instructions for GCC 4.9.4-VLE

This document provides step-by-step instructions for building GCC 4.9.4-VLE on Ubuntu 24.04.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [System Requirements](#system-requirements)
3. [Installing Dependencies](#installing-dependencies)
4. [Building with Docker (Recommended)](#building-with-docker-recommended)
5. [Building GCC](#building-gcc)
6. [Testing](#testing)
7. [Installation](#installation)
8. [Creating a Debian Package (.deb)](#creating-a-debian-package-deb)

## Prerequisites

This guide assumes you are working on a clean Ubuntu 24.04 system or have administrator privileges to install packages.

## System Requirements

- Ubuntu 24.04 (or compatible Debian-based distribution)
- At least 2GB of free disk space (more recommended for full build)
- Root or sudo access for package installation

## Installing Dependencies

### Update Package Lists

First, update your package lists:

```bash
sudo apt update
```

### Essential Build Tools

Install the essential build tools required for compiling GCC:

```bash
sudo apt install -y \
    build-essential \
    g++ \
    make \
    binutils \
    gcc \
    gzip \
    bzip2 \
    tar
```

### Required Libraries

GCC 4.9.4 requires several mathematical libraries. Install the development packages:

```bash
sudo apt install -y \
    libgmp-dev \
    libmpfr-dev \
    libmpc-dev
```

**Note:** These packages typically provide versions newer than the minimum required by GCC 4.9.4:
- GMP: requires 4.3.2+ (Ubuntu 24.04 provides 6.3.0+)
- MPFR: requires 2.4.2+ (Ubuntu 24.04 provides 4.2.0+)
- MPC: requires 0.8.1+ (Ubuntu 24.04 provides 1.3.1+)

### Optional: Graphite Loop Optimization Libraries

For Graphite loop optimizations (optional but recommended), install ISL and CLooG:

```bash
sudo apt install -y \
    libisl-dev \
    libcloog-isl-dev
```

**Note:** GCC 4.9.4 expects ISL 0.12.2 and CLooG 0.18.1, but Ubuntu 24.04 may provide newer versions. If you encounter compatibility issues, you may need to build these from source with the specific versions.

### Additional Build Dependencies

Install other tools required for the build process:

```bash
sudo apt install -y \
    gawk \
    perl \
    zlib1g-dev \
    libc6-dev \
    libstdc++-dev
```

For 64-bit builds that also support 32-bit targets (multilib), install 32-bit development libraries:

```bash
sudo apt install -y \
    gcc-multilib \
    g++-multilib
```

If you plan to build without multilib support, you can skip the multilib packages and configure with `--disable-multilib`.

### Documentation Build Tools (Optional)

If you want to build documentation:

```bash
sudo apt install -y \
    texinfo \
    texlive-base \
    texlive-latex-base \
    texlive-latex-extra
```

### Summary: All Dependencies in One Command

For convenience, here's a single command to install all required dependencies:

```bash
sudo apt update && sudo apt install -y \
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
    libcloog-isl-dev \
    gawk \
    perl \
    zlib1g-dev \
    libc6-dev \
    libstdc++-dev \
    gcc-multilib \
    g++-multilib
```

## Building with Docker (Recommended)

For a repeatable, isolated build environment, use the provided Docker setup.

### Quick Start

Build GCC using Docker:

```bash
./build.sh
```

This will:
1. Build the Docker image with all dependencies
2. Configure GCC
3. Compile GCC (may take several hours)
4. Package GCC into both `.deb` and `.tar.bz2` artifacts

The build artifacts will be in `./output/` directory:
- `gcc-4.9.4-vle_1_<arch>.deb` - Debian package ready for installation
- `gcc-4.9.4-vle-<arch>.tar.bz2` - Compressed archive of the complete compiler

The build output will be in `../gcc-build/` directory.

### Manual Docker Usage

Build the image:

```bash
docker build -t gcc-4.9.4-vle-builder .
```

Run the build:

```bash
mkdir -p ../gcc-build
docker run --rm \
    -v $(pwd):/src/gcc-4.9.4-vle:ro \
    -v $(pwd)/../gcc-build:/build/gcc-build \
    gcc-4.9.4-vle-builder
```

## Building GCC

### Configure the Build

Create a build directory outside the source tree (recommended):

```bash
mkdir -p ../gcc-build
cd ../gcc-build
```

Run configure with appropriate options:

```bash
../gcc-4.9.4-vle/configure \
    --prefix=/usr/local/gcc-4.9.4-vle \
    --enable-languages=c,c++ \
    --enable-threads=posix \
    --disable-bootstrap \
    --disable-multilib
```

**Configure Options Explained:**
- `--prefix=/usr/local/gcc-4.9.4-vle`: Installation prefix (change as needed)
- `--enable-languages=c,c++`: Languages to build (add others as needed: fortran,ada,go,objc,obj-c++)
- `--enable-threads=posix`: Thread model for libgomp
- `--disable-bootstrap`: Skip the 3-stage bootstrap (faster but less tested)
- `--disable-multilib`: Disable 32-bit support on 64-bit systems (use if you skipped multilib packages)

**For a production build with bootstrap (recommended):**

```bash
../gcc-4.9.4-vle/configure \
    --prefix=/usr/local/gcc-4.9.4-vle \
    --enable-languages=c,c++ \
    --enable-threads=posix \
    --enable-bootstrap
```

### Compile

Build GCC (this may take several hours depending on your system):

```bash
make -j$(nproc)
```

The `-j$(nproc)` option uses all available CPU cores for faster compilation.

### Installation

After successful compilation, install GCC:

```bash
sudo make install
```

Add to your PATH:

```bash
export PATH=/usr/local/gcc-4.9.4-vle/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/gcc-4.9.4-vle/lib64:$LD_LIBRARY_PATH
```

To make this permanent, add these lines to your `~/.bashrc`:

```bash
echo 'export PATH=/usr/local/gcc-4.9.4-vle/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/gcc-4.9.4-vle/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
```

## Testing

### Run the Test Suite (Optional)

To run the GCC test suite (this can take a long time):

```bash
cd ../gcc-build
make -k check
```

View test results:

```bash
cat gcc/testsuite/*.sum
```

## Creating a Debian Package (.deb)

### Install Packaging Tools

Install tools needed for creating Debian packages:

```bash
sudo apt install -y \
    dpkg-dev \
    debhelper \
    fakeroot \
    lintian
```

### Using checkinstall (Simple Method)

The simplest way to create a .deb package is using `checkinstall`:

```bash
sudo apt install -y checkinstall
```

After building GCC, instead of running `make install`, run:

```bash
sudo checkinstall \
    --pkgname=gcc-4.9.4-vle \
    --pkgversion=4.9.4 \
    --pkgrelease=1 \
    --pkglicense=GPL \
    --maintainer="Your Name <your.email@example.com>" \
    --provides=gcc-4.9.4-vle \
    make install
```

This will create a `.deb` package in your build directory.

### Using debhelper (Advanced Method)

For more control over the package, create a Debian package structure:

1. Create package directory structure:

```bash
mkdir -p debian-package/gcc-4.9.4-vle
cd debian-package/gcc-4.9.4-vle
```

2. Install GCC to a staging directory:

```bash
DESTDIR=$(pwd)/debian/gcc-4.9.4-vle make install
```

3. Create control files (this is a simplified approach - for production you'd want a full debian/ directory with proper rules):

```bash
mkdir -p debian
cat > debian/control << EOF
Package: gcc-4.9.4-vle
Version: 4.9.4-1
Section: devel
Priority: optional
Architecture: amd64
Depends: libc6 (>= 2.17), libgcc1 (>= 1:4.1.1), libstdc++6 (>= 4.1.1)
Maintainer: Your Name <your.email@example.com>
Description: GCC 4.9.4 with VLE support
 The GNU Compiler Collection with Variable Length Encoding support.
EOF
```

4. Build the package:

```bash
dpkg-deb --build debian/gcc-4.9.4-vle
```

## Troubleshooting

### Missing Headers (32-bit stubs error)

If you encounter `fatal error: gnu/stubs-32.h: No such file or directory`, either:
- Install 32-bit development libraries: `sudo apt install -y libc6-dev-i386`
- Or configure with `--disable-multilib` to skip 32-bit support

### Library Version Mismatches

If you encounter issues with ISL or CLooG versions, you may need to build them from source with the exact versions GCC expects:
- ISL 0.12.2
- CLooG 0.18.1

Download from: `ftp://gcc.gnu.org/pub/gcc/infrastructure/`

### Build Failures

If the build fails:
1. Check that all dependencies are installed
2. Ensure you have sufficient disk space
3. Review the error messages in the build output
4. Try building without parallel jobs: `make` instead of `make -j$(nproc)`

## Next Steps

After successful installation:
1. Verify the installation: `gcc-4.9.4-vle --version`
2. Update your system's alternatives (optional): `sudo update-alternatives --install /usr/bin/gcc gcc /usr/local/gcc-4.9.4-vle/bin/gcc 100`
3. Consider creating symbolic links or wrapper scripts as needed

## References

- GCC Installation Documentation: `gcc/doc/install.texi`
- Ubuntu Package Search: https://packages.ubuntu.com/
- GCC Prerequisites: http://gcc.gnu.org/install/prerequisites.html

