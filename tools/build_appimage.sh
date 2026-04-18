#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Building Flutter Linux Release ==="
flutter build linux --release

echo "=== Downloading appimagetool ==="
curl -fSL "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" \
  -o appimagetool
chmod +x appimagetool

echo "=== Creating AppDir ==="
APP=Streame.AppDir
rm -rf "$APP"
mkdir -p "$APP"

cp -r build/linux/x64/release/bundle/* "$APP/"
cp assets/icon/icon.png "$APP/Streame.png"
cp installer/linux/Streame.desktop "$APP/"

echo "=== Creating AppRun ==="
printf '#!/bin/bash\ncd "$(dirname "$0")"\nexec ./Streame "$@"\n' \
  > "$APP/AppRun"
chmod +x "$APP/AppRun"

echo "=== Building AppImage ==="
ARCH=x86_64 ./appimagetool --appimage-extract-and-run \
  "$APP" Streame-Linux-x86_64.AppImage

echo "=== Done ==="
echo "Output: Streame-Linux-x86_64.AppImage"
