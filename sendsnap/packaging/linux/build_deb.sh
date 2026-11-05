#!/usr/bin/env bash
# SendSnap Debian/Ubuntu (.deb) Package Builder
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEB_DIR="$PROJECT_ROOT/build/deb_package"
DIST_DIR="$PROJECT_ROOT/dist/linux"
VERSION="2.2.2"

echo "=== Building SendSnap .deb Package ==="

# 1. Build Flutter Linux Release
cd "$PROJECT_ROOT"
flutter build linux --release

# 2. Prepare .deb File Tree
rm -rf "$DEB_DIR"
mkdir -p "$DEB_DIR/opt/sendsnap"
mkdir -p "$DEB_DIR/usr/bin"
mkdir -p "$DEB_DIR/usr/share/applications"
mkdir -p "$DEB_DIR/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$DEB_DIR/DEBIAN"
mkdir -p "$DIST_DIR"

# Copy binaries
cp -r "$PROJECT_ROOT/build/linux/x64/release/bundle/"* "$DEB_DIR/opt/sendsnap/"

# Symlink to /usr/bin
ln -sf /opt/sendsnap/sendsnap "$DEB_DIR/usr/bin/sendsnap"

# Copy Desktop entry and Icon
cp "$SCRIPT_DIR/com.the356company.sendsnap.desktop" "$DEB_DIR/usr/share/applications/"
cp "$PROJECT_ROOT/assets/icon/app_icon.png" "$DEB_DIR/usr/share/icons/hicolor/256x256/apps/sendsnap.png"

# Write DEBIAN/control file
cat << EOF > "$DEB_DIR/DEBIAN/control"
Package: sendsnap
Version: $VERSION
Section: net
Priority: optional
Architecture: amd64
Maintainer: The 356 Company <support@the356company.com>
Description: SendSnap - Fast Nearby File Share
 Fast, secure, cross-platform local network file sharing with ethereal handoff gestures.
EOF

# 3. Build .deb package
dpkg-deb --build "$DEB_DIR" "$DIST_DIR/sendsnap_${VERSION}_amd64.deb"
echo "Package created at $DIST_DIR/sendsnap_${VERSION}_amd64.deb"
