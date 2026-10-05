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

# The default web app list is data, not code: it is the seeding source for a new
# install, so leaving it out of the bundle would silently seed nothing.
if [ -f "$DIR/Resources/DefaultWebApps.json" ]; then
    echo "📋 Copying DefaultWebApps.json into bundle..."
    cp "$DIR/Resources/DefaultWebApps.json" "$RESOURCES_DIR/DefaultWebApps.json"
else
    echo "❌ Resources/DefaultWebApps.json is missing — a new install would seed no default web apps." >&2
    exit 1
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

# Install to /Applications, and nowhere else.
#
# This is the single copy that gets launched and observed, so it must be the bundle
# that was just built. Installing anywhere else as well would put two copies of the
# same bundle id on the machine, and which one Launch Services resolves is not
# something a test session should depend on — a stale winner makes a correct change
# look like it did nothing.
INSTALL_DIR="/Applications"

# Installing must not depend on the caller's shell or prompt for a password: an
# automated run has nobody to type one. So probe writability first and fail loudly
# with the exact command to run, rather than falling back to a second location —
# a fallback would recreate the duplicate this install is meant to prevent.
if [ ! -w "$INSTALL_DIR" ]; then
    echo ""
    echo "❌ $INSTALL_DIR is not writable by $(whoami)."
    echo "   Re-run with elevated rights, then launch from the result:"
    echo ""
    echo "     sudo $DIR/scripts/build_app.sh"
    echo ""
    echo "   Not falling back to another directory on purpose: two copies of the"
    echo "   same bundle id make 'did my change take effect?' unanswerable."
    exit 1
fi

echo "🚚 Installing $APP_NAME.app to $INSTALL_DIR/..."
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$APP_BUNDLE" "$INSTALL_DIR/$APP_NAME.app"

# Report any copy that could shadow the one just installed. Deliberately not the
# repo-root copy: the script writes that itself, in the same run, so it is always in
# sync with the install and can never be the stale winner. Only a location nothing
# maintains any more is worth warning about — a warning that fires on every build
# is a warning people learn to skip. Do not delete the stray unasked, since it may
# be the user's own, but never leave the choice to chance either.
STRAY="$HOME/Applications/$APP_NAME.app"
if [ -d "$STRAY" ]; then
    echo ""
    echo "⚠️  Another copy exists at $STRAY"
    echo "    Same bundle id, and nothing updates it any more — Launch Services may"
    echo "    launch it, making a correct change look like it did nothing."
    echo "    Remove it with: rm -rf \"$STRAY\""
fi

echo ""
echo "✅ Successfully built and installed $APP_NAME.app to $INSTALL_DIR/!"
echo "🚀 Relaunch it with: open $INSTALL_DIR/$APP_NAME.app"
