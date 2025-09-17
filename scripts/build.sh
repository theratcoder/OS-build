#!/usr/bin/env bash
set -euo pipefail

# Patched build script for RatOS
# - safer kernel build / save bzImage
# - install kernel headers with headers_install
# - robust extraction of sources
# - build glibc once and install into ROOTFS
# - build ncurses with widec + symlinks (for libtinfo/libncurses)
# - build bash and install into ROOTFS
# - create static init and device nodes

# Adjust these paths to fit your layout
SOURCES_DIR="$HOME/RatOS/build/sources"
BUILD_DIR="$HOME/RatOS/build"
KERNEL_SRC="$HOME/RatOS/kernel"
KERNEL_OUT="$BUILD_DIR/build/kernel"
ROOTFS="$BUILD_DIR/rootfs"

mkdir -p "$KERNEL_OUT"
mkdir -p "$BUILD_DIR/build"
mkdir -p "$ROOTFS"

# ---------------------------
# Kernel: build bzImage and headers safely
# ---------------------------
cd "$KERNEL_SRC"

# If you have a saved .config, restore it; otherwise use defconfig
if [ -f "$HOME/RatOS/kernel.config" ]; then
  echo "Restoring saved kernel .config"
  cp "$HOME/RatOS/kernel.config" .config
else
  if [ ! -f .config ]; then
    echo ".config not found; using defconfig"
    make defconfig
  fi
fi

# Build bzImage
make -j"$(nproc)" bzImage
cp -v arch/x86_64/boot/bzImage "$KERNEL_OUT/bzImage-$(date +%Y%m%d-%H%M%S)"

# Install kernel headers for glibc
make headers_install INSTALL_HDR_PATH="$ROOTFS/usr"

# sanitize: remove Makefile if present (LFS recommendation)
if [ -f usr/include/Makefile ]; then
  rm -f usr/include/Makefile
fi

# Ensure headers are where glibc will look
if [ ! -d "$ROOTFS/usr/include/linux" ]; then
  echo "ERROR: kernel headers not found under $ROOTFS/usr/include/linux"
  exit 1
fi

# ---------------------------
# Build glibc
# ---------------------------
GLIBC_TAR="$SOURCES_DIR/glibc-2.39.tar.xz"
GLIBC_BUILD_DIR="$BUILD_DIR/build/glibc/build"

rm -rf "$BUILD_DIR/build/glibc"
mkdir -p "$BUILD_DIR/build/glibc"

mkdir -p "$GLIBC_BUILD_DIR"

tar xf "$GLIBC_TAR" -C "$BUILD_DIR/build/glibc"

cd "$GLIBC_BUILD_DIR"

"../glibc-2.39/configure" \
  --prefix=/usr \
  --disable-werror \
  --enable-kernel=4.19 \
  --with-headers="$ROOTFS/usr/include" \
  --build=$(../glibc-2.39/scripts/config.guess)

make -j"$(nproc)"
make DESTDIR="$ROOTFS" install

# Verify installed files
if [ ! -d "$ROOTFS/lib64" ] && [ ! -d "$ROOTFS/lib" ]; then
  echo "ERROR: glibc install did not create lib or lib64 in $ROOTFS"
  exit 1
fi

# ---------------------------
# Build ncurses (widec + termlib + compatibility symlinks)
# ---------------------------
NCURSES_TAR="$SOURCES_DIR/ncurses.tar.gz"
NCURSES_SRC_DIR="$BUILD_DIR/build/ncurses/ncurses-6.3"

rm -rf "$BUILD_DIR/build/ncurses"
mkdir -p "$BUILD_DIR/build/ncurses"

tar xf "$NCURSES_TAR" -C "$BUILD_DIR/build/ncurses"

cd "$NCURSES_SRC_DIR"

./configure \
  --prefix=/usr \
  --libdir=/usr/lib \
  --with-shared \
  --without-debug \
  --without-ada \
  --with-termlib \
  --build=$(./config.guess)

make -j"$(nproc)"
make DESTDIR="$ROOTFS" install

# Add compatibility symlinks so programs find libtinfo/libncurses without 'w'
cd "$ROOTFS/usr/lib"
if [ -f libtinfow.so.6 ] && [ ! -f libtinfo.so.6 ]; then
  ln -sv libtinfow.so.6 libtinfo.so.6
fi
if [ -f libncursesw.so.6 ] && [ ! -f libncurses.so.6 ]; then
  ln -sv libncursesw.so.6 libncurses.so.6
fi

# ---------------------------
# Build bash
# ---------------------------
BASH_TAR="$SOURCES_DIR/bash-5.2.21.tar.gz"
BASH_SRC_DIR="$BUILD_DIR/build/bash/bash-5.2.21"

rm -rf "$BUILD_DIR/build/bash"
mkdir -p "$BUILD_DIR/build/bash"

tar xf "$BASH_TAR" -C "$BUILD_DIR/build/bash"

cd "$BASH_SRC_DIR"

./configure --prefix=/usr --build=$(./support/config.guess)
make -j"$(nproc)"
make DESTDIR="$ROOTFS" install

# install dash
# Dash version (latest stable as of Debian/bookworm = 0.5.12)
DASH_VERSION=0.5.12
DASH_TAR="dash-${DASH_VERSION}.tar.gz"
DASH_URL="http://gondor.apana.org.au/~herbert/dash/files/$DASH_TAR"
DASH_SRC_DIR="$BUILD_DIR/build/dash/dash-${DASH_VERSION}"

# Ensure dirs
mkdir -p "$SOURCES_DIR" "$BUILD_DIR/build/dash" "$ROOTFS/bin"

# Download if not present
if [ ! -f "$SOURCES_DIR/$DASH_TAR" ]; then
  echo "Downloading dash-$DASH_VERSION..."
  wget -O "$SOURCES_DIR/$DASH_TAR" "$DASH_URL"
fi

# Extract
rm -rf "$BUILD_DIR/build/dash"
mkdir -p "$BUILD_DIR/build/dash"
tar xf "$SOURCES_DIR/$DASH_TAR" -C "$BUILD_DIR/build/dash"

# Build dash
cd "$DASH_SRC_DIR"
./configure --prefix=/usr --build=$(./config.guess)
make -j"$(nproc)"

# Install into rootfs
make DESTDIR="$ROOTFS" install

# Create symlink for /bin/sh -> dash
ln -svf dash "$ROOTFS/bin/sh"

echo "Dash installed successfully to $ROOTFS/bin/dash"
echo "Symlink created: /bin/sh -> dash"

# coreutils (cp, ls, etc.)
COREUTILS_VERSION=9.2
COREUTILS_TAR="coreutils-${COREUTILS_VERSION}.tar.xz"
COREUTILS_URL="https://ftp.gnu.org/gnu/coreutils/$COREUTILS_TAR"
COREUTILS_SRC_DIR="$BUILD_DIR/build/coreutils/coreutils-${COREUTILS_VERSION}"

# Ensure dirs
mkdir -p "$SOURCES_DIR" "$BUILD_DIR/build/coreutils"

# Download if missing
if [ ! -f "$SOURCES_DIR/$COREUTILS_TAR" ]; then
  echo "Downloading coreutils-$COREUTILS_VERSION..."
  wget -O "$SOURCES_DIR/$COREUTILS_TAR" "$COREUTILS_URL"
fi

# Extract
rm -rf "$BUILD_DIR/build/coreutils"
mkdir -p "$BUILD_DIR/build/coreutils"
tar xf "$SOURCES_DIR/$COREUTILS_TAR" -C "$BUILD_DIR/build/coreutils"

# Build coreutils
cd "$COREUTILS_SRC_DIR"
./configure --prefix=/usr --build=$(./build-aux/config.guess)
make -j"$(nproc)"

# Install into rootfs
make DESTDIR="$ROOTFS" install

echo "Coreutils installed successfully into $ROOTFS"

# ---------------------------
# Small init program
# ---------------------------
cd "$HOME/RatOS/userland/init"
# compile static init (if it uses only libc functions this may fail; keep as fallback)
gcc -static -o init init.c || gcc -o init init.c
cp -v init "$ROOTFS/init"
chmod +x "$ROOTFS/init"

# ---------------------------
# Devices and mountpoints
# ---------------------------
sudo mkdir -p "$ROOTFS/dev"
if [ ! -e "$ROOTFS/dev/console" ]; then
  sudo mknod -m 600 "$ROOTFS/dev/console" c 5 1
fi
if [ ! -e "$ROOTFS/dev/null" ]; then
  sudo mknod -m 666 "$ROOTFS/dev/null" c 1 3
fi

mkdir -p "$ROOTFS/{proc,sys}"

echo "Build completed. Kernel saved to: $KERNEL_OUT"
echo "Rootfs populated under: $ROOTFS"

exit 0