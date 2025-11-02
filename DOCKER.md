# Docker Build System for GCC 4.9.4-VLE

This document describes the Docker-based build system for GCC 4.9.4-VLE, which provides a repeatable, isolated build environment that produces both `.deb` and `.tar.bz2` artifacts.

## Overview

The Docker build system:
- **Ingests** the source directory via volume mount
- **Builds** GCC 4.9.4-VLE with all dependencies included
- **Emits** both `.deb` (Debian package) and `.tar.bz2` (compressed archive) artifacts

## Architecture

### Components

1. **Dockerfile** - Base image with all build dependencies
2. **build-and-package.sh** - Build script that runs inside the container (produces both .deb and .tar.bz2)
3. **build.sh** - Unified build wrapper script

### Directory Structure

```
/projects/gcc-4.9.4-vle/          # Source directory (mounted as /src/gcc-4.9.4-vle)
├── Dockerfile
├── build.sh                       # Main entry point - builds Docker image and runs build
├── build-and-package.sh           # Build script that runs inside container
├── output/                         # Output artifacts (mounted as /workspace/output)
│   ├── gcc-4.9.4-vle_1_<arch>.deb
│   └── gcc-4.9.4-vle-<arch>.tar.bz2
└── ../gcc-build/                   # Build directory (mounted as /build/gcc-build)
```

## Quick Start

### Automated Build

```bash
./build.sh
```

This will:
1. Build the Docker image (first time only)
2. Configure and compile GCC
3. Create both `.deb` and `.tar.bz2` artifacts
4. Save artifacts to `./output/` directory

### Manual Docker Usage

For debugging or manual builds, you can run the container interactively:

```bash
docker build -t gcc-4.9.4-vle-builder .
docker run --rm -it \
    -v $(pwd):/src/gcc-4.9.4-vle:ro \
    -v $(pwd)/../gcc-build:/build/gcc-build \
    -v $(pwd)/output:/workspace/output \
    gcc-4.9.4-vle-builder \
    bash
```

## Detailed Usage

### Building the Docker Image

```bash
docker build -t gcc-4.9.4-vle-builder .
```

### Running the Build Manually

```bash
mkdir -p output
docker run --rm \
    -v $(pwd):/src/gcc-4.9.4-vle:ro \
    -v $(pwd)/../gcc-build:/build/gcc-build \
    -v $(pwd)/output:/workspace/output \
    gcc-4.9.4-vle-builder
```

### Environment Variables

The build script supports the following environment variables (with defaults):

- `SOURCE_DIR` - Source directory inside container (default: `/src/gcc-4.9.4-vle`)
- `BUILD_DIR` - Build directory inside container (default: `/build/gcc-build`)
- `PREFIX` - Installation prefix (default: `/usr/local/gcc-4.9.4-vle`)
- `OUTPUT_DIR` - Output directory for artifacts (default: `/workspace/output`)
- `GCC_VERSION` - GCC version (default: `4.9.4`)
- `GCC_RELEASE` - Package release number (default: `1`)

Example with custom variables:

```bash
docker run --rm \
    -v $(pwd):/src/gcc-4.9.4-vle:ro \
    -v $(pwd)/output:/workspace/output \
    -e GCC_RELEASE=2 \
    -e PREFIX=/opt/gcc-4.9.4-vle \
    gcc-4.9.4-vle-builder
```

## Build Process

### Phase 1: Configuration

The build script runs `configure` with these options:
- `--prefix=${PREFIX}` - Installation prefix
- `--enable-languages=c,c++` - Build C and C++ compilers
- `--enable-threads=posix` - POSIX thread model
- `--disable-bootstrap` - Skip 3-stage bootstrap (faster build)

### Phase 2: Compilation

Builds GCC using all available CPU cores:
```bash
make -j$(nproc)
```

### Phase 3: Installation

Installs GCC to a staging directory:
```bash
DESTDIR=/tmp/gcc-install make install
```

### Phase 4: Packaging

#### .tar.bz2 Archive

Creates a compressed archive of the complete installation:
```bash
tar -cjf ${OUTPUT_DIR}/gcc-${VERSION}-vle-$(uname -m).tar.bz2 \
    --transform "s,^gcc-install/,gcc-${VERSION}-vle/," \
    gcc-install/
```

The archive structure is:
```
gcc-4.9.4-vle/
└── usr/local/gcc-4.9.4-vle/
    ├── bin/
    ├── lib/
    ├── include/
    └── ...
```

#### .deb Package

Attempts to create a Debian package using `checkinstall`, with fallback to manual `dpkg-deb` method:

**Using checkinstall:**
```bash
checkinstall \
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
    --pakdir=${OUTPUT_DIR}
```

**Manual fallback:**
If `checkinstall` fails, creates `.deb` manually using `dpkg-deb` with proper control file.

## Dependencies

The Dockerfile installs all required dependencies:

### Build Tools
- `build-essential` - GCC, G++, Make, etc.
- `gcc-multilib`, `g++-multilib` - Multilib support
- `binutils` - Binary utilities

### Mathematical Libraries
- `libgmp-dev` - GNU Multiple Precision Library
- `libmpfr-dev` - Multiple Precision Floating-Point
- `libmpc-dev` - Multiple Precision Complex
- `libisl-dev` - Integer Set Library

### Packaging Tools
- `checkinstall` - Debian package creation
- `dpkg-dev` - Debian packaging tools
- `fakeroot` - Fake root environment

### Other Dependencies
- `gawk`, `perl`, `zlib1g-dev`, `libc6-dev`

## Output Artifacts

### .deb Package

**Name format:** `gcc-4.9.4-vle_1_<arch>.deb`

**Installation:**
```bash
sudo dpkg -i output/gcc-4.9.4-vle_1_amd64.deb
```

**Package contents:**
- Installs to `/usr/local/gcc-4.9.4-vle/`
- Includes binaries, libraries, headers, and documentation

### .tar.bz2 Archive

**Name format:** `gcc-4.9.4-vle-<arch>.tar.bz2`

**Extraction:**
```bash
tar -xjf output/gcc-4.9.4-vle-x86_64.tar.bz2
cd gcc-4.9.4-vle
# Files are in usr/local/gcc-4.9.4-vle/
```

## Troubleshooting

### Build Fails During Configuration

**Issue:** Missing dependencies

**Solution:** Ensure all packages are installed. The Dockerfile should handle this automatically, but verify the image was built correctly:

```bash
docker build -t gcc-4.9.4-vle-builder . 2>&1 | tee build.log
```

### checkinstall Fails

**Issue:** checkinstall cannot create package

**Solution:** The build script automatically falls back to manual `.deb` creation using `dpkg-deb`. This is normal and both methods produce valid packages.

### Out of Disk Space

**Issue:** Build fails with "No space left on device"

**Solution:** GCC build requires significant disk space (several GB). Clean up Docker images and containers:

```bash
docker system prune -a
```

Or build on a system with more available space.

### Build Takes Too Long

**Issue:** Build is very slow

**Solution:** 
- The build uses all CPU cores by default (`-j$(nproc)`)
- Ensure Docker has adequate CPU and memory resources allocated
- Consider building with fewer parallel jobs: Edit `build-and-package.sh` and change `make -j$(nproc)` to `make -j4`

### Missing /usr/bin/file

**Issue:** Configure script complains about missing `/usr/bin/file`

**Solution:** Install `file` package. Add to Dockerfile:
```dockerfile
apt-get install -y file
```

## Customization

### Changing Build Options

Edit `build-and-package.sh` to modify configure options:

```bash
${SOURCE_DIR}/configure \
    --prefix=${PREFIX} \
    --enable-languages=c,c++,fortran \  # Add more languages
    --enable-threads=posix \
    --enable-bootstrap \                 # Enable bootstrap
    --disable-multilib                   # Disable multilib
```

### Different Installation Prefix

Set `PREFIX` environment variable:

```bash
docker run --rm \
    -v $(pwd):/src/gcc-4.9.4-vle:ro \
    -v $(pwd)/output:/workspace/output \
    -e PREFIX=/opt/gcc-custom \
    gcc-4.9.4-vle-builder
```

### Building on Different Architecture

The build automatically detects architecture. To cross-compile, modify configure options and set appropriate `--target` flag.

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Build GCC

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build Docker image
        run: docker build -t gcc-4.9.4-vle-builder .
      - name: Build GCC
        run: ./build.sh
      - name: Upload artifacts
        uses: actions/upload-artifact@v2
        with:
          path: output/
```

## File Reference

- **Dockerfile** - Container image definition
- **build-and-package.sh** - Main build script (runs in container, produces both .deb and .tar.bz2)
- **build.sh** - Unified build wrapper script
- **.dockerignore** - Files excluded from Docker context

## Portability

The Dockerfile uses:
- **Base Image:** `ubuntu:24.04` - Standard Ubuntu 24.04 LTS
- **No Hardcoded Paths** - All paths are configurable via environment variables or volume mounts
- **Standard Tools** - Only uses standard Debian/Ubuntu packages

This makes the build system portable and uploadable to any Docker-compatible system.

## License

The build system is provided under the same license as GCC (GPL v3+).

