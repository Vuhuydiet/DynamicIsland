#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "🔨 Building Dynamic Island for macOS..."

APP_NAME="DynamicIsland"
BUILD_DIR="$DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Collect all swift files
SWIFT_FILES=$(find Sources/DynamicIsland -name "*.swift")

echo "📦 Compiling Swift sources..."
DEVELOPER_DIR=/Library/Developer/CommandLineTools xcrun swiftc \
    -O \
    -target arm64-apple-macosx14.0 \
    -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
    -framework AppKit \
    -framework SwiftUI \
    -framework Combine \
    -framework IOKit \
    -framework AudioToolbox \
    -framework UserNotifications \
    -framework ServiceManagement \
    $SWIFT_FILES \
    -o "$MACOS_DIR/$APP_NAME"

if [ -f "$DIR/scripts/AppIcon.icns" ]; then
    cp "$DIR/scripts/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

echo "📝 Creating Info.plist..."
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>DynamicIsland</string>
    <key>CFBundleDisplayName</key>
    <string>Dynamic Island</string>
    <key>CFBundleIdentifier</key>
    <string>com.dynamicisland.mac</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>DynamicIsland</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Dynamic Island uses Apple Events to display and control now-playing media from Apple Music and Spotify.</string>
</dict>
</plist>
EOF

chmod +x "$MACOS_DIR/$APP_NAME"

# Also symlink or copy to root for quick access
rm -rf "$DIR/$APP_NAME.app"
cp -R "$APP_BUNDLE" "$DIR/$APP_NAME.app"

echo "✅ Successfully built $APP_NAME.app!"
echo "🚀 You can launch it using: open $DIR/$APP_NAME.app"
