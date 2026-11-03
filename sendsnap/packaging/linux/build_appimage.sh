#!/usr/bin/env bash
# SendSnap Universal Linux AppImage Builder
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_DIR="$PROJECT_ROOT/build/AppDir"
DIST_DIR="$PROJECT_ROOT/dist/linux"

echo "=== Building SendSnap AppImage for Linux ==="

# 1. Build Flutter Linux Release
cd "$PROJECT_ROOT"
flutter build linux --release

# 2. Prepare AppDir Structure
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/usr/bin"
mkdir -p "$APP_DIR/usr/lib"
mkdir -p "$APP_DIR/usr/share/applications"
mkdir -p "$APP_DIR/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$DIST_DIR"

# Copy Flutter release binaries and bundle
cp -r "$PROJECT_ROOT/build/linux/x64/release/bundle/"* "$APP_DIR/usr/bin/"

# Copy Desktop Entry and Icons
cp "$SCRIPT_DIR/com.the356company.sendsnap.desktop" "$APP_DIR/usr/share/applications/"
cp "$SCRIPT_DIR/com.the356company.sendsnap.desktop" "$APP_DIR/"
cp "$PROJECT_ROOT/assets/icon/app_icon.png" "$APP_DIR/usr/share/icons/hicolor/256x256/apps/sendsnap.png"
cp "$PROJECT_ROOT/assets/icon/app_icon.png" "$APP_DIR/sendsnap.png"

# Create AppRun entrypoint
cat << 'EOF' > "$APP_DIR/AppRun"
#!/bin/sh
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${HERE}/usr/bin/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/usr/bin/sendsnap" "$@"
EOF
chmod +x "$APP_DIR/AppRun"

# 3. Generate AppImage using appimagetool if installed
if command -v appimagetool &> /dev/null; then
    echo "Running appimagetool..."
    appimagetool "$APP_DIR" "$DIST_DIR/SendSnap-x86_64.AppImage"
    echo "AppImage created successfully at $DIST_DIR/SendSnap-x86_64.AppImage"
else
    echo "appimagetool not found. To create the final single .AppImage file, download appimagetool:"
    echo "wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O /usr/local/bin/appimagetool && chmod +x /usr/local/bin/appimagetool"
    echo "AppDir structure is ready at $APP_DIR"
fi
