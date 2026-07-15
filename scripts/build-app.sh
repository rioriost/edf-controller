#!/bin/zsh

set -euo pipefail

ROOT_DIR="${0:A:h:h}"
VERSION="${VERSION:-0.1.2}"
APP_NAME="Edifier Controller"
EXECUTABLE_NAME="EdifierController"
BUILD_DIR="$ROOT_DIR/.build/app"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.png"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
IDENTITY="${CODE_SIGN_IDENTITY:--}"

rm -rf "$BUILD_DIR" "$APP_DIR"

swift build \
  --package-path "$ROOT_DIR" \
  --configuration release \
  --arch arm64 \
  --arch x86_64 \
  --scratch-path "$BUILD_DIR"

mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
install -m 755 \
  "$BUILD_DIR/apple/Products/Release/$EXECUTABLE_NAME" \
  "$CONTENTS_DIR/MacOS/$EXECUTABLE_NAME"
install -m 644 "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

mkdir -p "$ICONSET_DIR"
sips --resampleHeightWidth 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips --resampleHeightWidth 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips --resampleHeightWidth 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips --resampleHeightWidth 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips --resampleHeightWidth 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips --resampleHeightWidth 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips --resampleHeightWidth 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips --resampleHeightWidth 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips --resampleHeightWidth 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips --resampleHeightWidth 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$CONTENTS_DIR/Resources/AppIcon.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$CONTENTS_DIR/Info.plist"

if [[ "$IDENTITY" == "-" ]]; then
  codesign --force --sign - "$APP_DIR"
else
  codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$IDENTITY" \
    "$APP_DIR"
fi

codesign --verify --deep --strict --verbose=2 "$APP_DIR"
plutil -lint "$CONTENTS_DIR/Info.plist"
test -f "$CONTENTS_DIR/Resources/AppIcon.icns"
file "$CONTENTS_DIR/MacOS/$EXECUTABLE_NAME"

print "Built: $APP_DIR"
