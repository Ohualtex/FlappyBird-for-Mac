#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="FlappyBird"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

swift build --package-path "$SCRIPT_DIR" -c release

BIN_DIR="$(swift build --package-path "$SCRIPT_DIR" -c release --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BIN_DIR/FlappyBirdMac" "$APP_BUNDLE/Contents/MacOS/FlappyBirdMac"
cp -R "$BIN_DIR/FlappyBirdMac_FlappyBirdMac.bundle" "$APP_BUNDLE/Contents/Resources/"

ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

swift - "$SCRIPT_DIR/Sources/FlappyBirdMac/Assets/app.ico" "$ICONSET_DIR" <<'SWIFT'
import AppKit
import CoreGraphics
import Foundation

let icoPath = CommandLine.arguments[1]
let iconsetPath = CommandLine.arguments[2]

guard let image = NSImage(contentsOfFile: icoPath),
      let bestRep = image.representations.max(by: { $0.pixelsWide < $1.pixelsWide }),
      let cgImage = bestRep.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("Failed to read app.ico")
}

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

let colorSpace = CGColorSpaceCreateDeviceRGB()
for (filename, size) in sizes {
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Failed to create CGContext for \(size)")
    }
    context.interpolationQuality = .none
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
    guard let scaled = context.makeImage() else {
        fatalError("Failed to render \(filename)")
    }
    let bitmap = NSBitmapImageRep(cgImage: scaled)
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode \(filename)")
    }
    try pngData.write(to: URL(fileURLWithPath: iconsetPath).appendingPathComponent(filename))
}
SWIFT

iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET_DIR"

cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>FlappyBirdMac</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.flappybird.mac</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Flappy Bird</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "Built $APP_BUNDLE"
