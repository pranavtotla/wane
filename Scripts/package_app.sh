#!/bin/bash
set -euo pipefail

APP_NAME="Wane"
BIN_PATH=$(swift build -c release --show-bin-path)

mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"
cp "$BIN_PATH/$APP_NAME" "$APP_NAME.app/Contents/MacOS/"
cp Sources/Wane/Resources/Info.plist "$APP_NAME.app/Contents/"

codesign --force --sign - "$APP_NAME.app"
echo "Packaged: $APP_NAME.app"
