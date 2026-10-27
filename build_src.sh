#!/bin/bash
set -euo pipefail

fish_VERSION=$1
BUILD_VERSION=$2

if [ -z "$fish_VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <fish_version> <build_version>"
    echo "Example: $0 4.8.1 1"
    exit 1
fi

PACKAGE_NAME="fish"
# fish publishes a real source tarball as a release asset; use it as the orig
# tarball so debian/rules can build the man pages from doc_src/.
ORIG_TARBALL="${PACKAGE_NAME}_${fish_VERSION}.orig.tar.xz"
BUILD_DIR="${PACKAGE_NAME}-${fish_VERSION}"

echo "Creating the source package for fish ${fish_VERSION}-${BUILD_VERSION}..."

# A rebuild of an upstream version already released here (a +N build bump)
# must ship the very same orig tarball: the pool holds one per upstream
# version and reprepro refuses a different one, and nothing guarantees the
# archive download is byte-identical next time. Reuse the earlier release's copy.
if [ ! -f "$ORIG_TARBALL" ]; then
    for ((b = BUILD_VERSION - 1; b >= 1; b--)); do
        if wget -q "https://github.com/gaofengnan/fish-shell-debian/releases/download/${fish_VERSION}%2B${b}/${ORIG_TARBALL}" -O "$ORIG_TARBALL"; then
            echo "  Reusing $ORIG_TARBALL from release ${fish_VERSION}+${b}"
            break
        fi
        rm -f "$ORIG_TARBALL"
    done
fi

# Download upstream source tarball (shared .orig.tar.xz across all distributions)
if [ ! -f "$ORIG_TARBALL" ]; then
    echo "Downloading upstream source from GitHub..."
    wget -q "https://github.com/fish-shell/fish-shell/releases/download/${fish_VERSION}/fish-${fish_VERSION}.tar.xz" -O "$ORIG_TARBALL"
    echo "  Downloaded $ORIG_TARBALL"
else
    echo "  Using existing $ORIG_TARBALL"
fi

build_source_package() {
    local FULL_VERSION="${fish_VERSION}-${BUILD_VERSION}~gaofn"

    echo "  Building source package ${FULL_VERSION}..."

    # Clean and recreate build directory from orig tarball
    rm -rf "$BUILD_DIR"
    tar -xf "$ORIG_TARBALL"
    # The upstream tarball extracts as fish-X.Y.Z/ which matches BUILD_DIR

    # Copy Debian packaging directory
    cp -r debian "$BUILD_DIR/"

    # Generate the changelog (overwrites placeholder)
    cat > "$BUILD_DIR/debian/changelog" << EOF
fish (${FULL_VERSION}) stable; urgency=medium

  * New upstream release ${fish_VERSION}.

 -- Fengnan Gao <gao.fengnan@gmail.com>  $(date -R)
EOF

    # Build source package (.dsc + .debian.tar.xz); reuses existing .orig.tar.xz
    dpkg-source -b "$BUILD_DIR"

    rm -rf "$BUILD_DIR"
    echo "    ${FULL_VERSION}"
}

echo ""
# One source package for every suite, as with the binaries (see build_debian.sh).
build_source_package

echo ""
echo "Source packages created successfully!"
echo ""
echo "Generated files:"
ls -la "${PACKAGE_NAME}_"*.dsc "${PACKAGE_NAME}_"*.orig.tar.xz "${PACKAGE_NAME}_"*.debian.tar.xz 2>/dev/null || true
