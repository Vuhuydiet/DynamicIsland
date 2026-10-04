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
    -framework CoreAudio \
    -framework AudioToolbox \
    -framework UserNotifications \
    -framework ServiceManagement \
    -framework WebKit \
    $SWIFT_FILES \
    -o "$MACOS_DIR/$APP_NAME"

if [ -f "$DIR/scripts/AppIcon.icns" ]; then
    cp "$DIR/scripts/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

if [ -d "$DIR/Resources/PluginIcons" ]; then
    echo "🎨 Copying PluginIcons into bundle..."
    mkdir -p "$RESOURCES_DIR/PluginIcons"
    cp -R "$DIR/Resources/PluginIcons/"* "$RESOURCES_DIR/PluginIcons/"
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
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSAppleEventsUsageDescription</key>
    <string>Dynamic Island uses Apple Events to display and control now-playing media from Apple Music and Spotify.</string>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>NSUserNotificationsUsageDescription</key>
    <string>Dynamic Island sends notifications when your countdown timer finishes.</string>
</dict>
</plist>
EOF

chmod +x "$MACOS_DIR/$APP_NAME"

# Copy to project root
rm -rf "$DIR/$APP_NAME.app"
cp -R "$APP_BUNDLE" "$DIR/$APP_NAME.app"

# Install to ~/Applications, NOT /Applications.
#
# The home copy is the one that gets launched and observed, so it must be the same
# bundle that was just built. Installing to /Applications instead would leave two
# copies of the same bundle id on the machine, and which one Launch Services picks
# is not something a test session should depend on.
#
# ~ is expanded explicitly rather than written as a literal ~ inside quotes, which
# would be a path that does not exist. $HOME in double quotes is already expanded,
# so this line is safe as written.
INSTALL_DIR="$HOME/Applications"
mkdir -p "$INSTALL_DIR"
echo "🚚 Installing $APP_NAME.app to $INSTALL_DIR/..."
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$APP_BUNDLE" "$INSTALL_DIR/$APP_NAME.app"

# A copy at the old location is a duplicate bundle id, and Launch Services does not
# guarantee which one it resolves. That makes "did my change take effect?" ambiguous,
# which defeats the point of installing. Report it; do not delete it unasked, since
# /Applications is outside the build's remit and may need elevated rights.
if [ -d "/Applications/$APP_NAME.app" ]; then
    echo ""
    echo "⚠️  A copy also exists at /Applications/$APP_NAME.app"
    echo "    Same bundle id — Launch Services may launch that one instead."
    echo "    Remove it with: sudo rm -rf /Applications/$APP_NAME.app"
fi

echo ""
echo "✅ Successfully built and installed $APP_NAME.app to $INSTALL_DIR/!"
echo "🚀 Relaunch it with: open $INSTALL_DIR/$APP_NAME.app"
