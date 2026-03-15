#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

ARCH=$(uname -m)  # arm64 or x86_64

echo "Building boofa-sketch for ${ARCH}..."

swiftc -parse-as-library \
    -target "${ARCH}-apple-macosx12.0" \
    -O \
    -o boofa-sketch \
    Sources/*.swift

echo "Creating .app bundle..."

mkdir -p BoofaSketch.app/Contents/{MacOS,Resources}
cp boofa-sketch BoofaSketch.app/Contents/MacOS/
cp Info.plist BoofaSketch.app/Contents/

echo "Done. Binary: boofa-sketch, Bundle: BoofaSketch.app"
