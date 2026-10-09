#!/bin/bash
set -euo pipefail

APP_NAME="Khipro"
VOLUME_NAME="Khipro Installer"
WORKSPACE="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$WORKSPACE/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
STAGING="$BUILD_DIR/dmg-staging"
BG_PATH="$WORKSPACE/Resources/dmg-bg.png"
ICON_PATH="$WORKSPACE/Resources/AppIcon.icns"

R='\033[0;31m'; G='\033[0;32m'; B='\033[0;34m'; NC='\033[0m'

echo -e "${B}== Creating DMG installer for $APP_NAME ==${NC}"

if [ ! -d "$APP_BUNDLE" ]; then
    echo -e "${R}Error: Build the app first: make bundle${NC}"
    exit 1
fi

# --- Generate background (designed, rendered natively via AppKit) ---
echo "  Rendering background..."
mkdir -p "$(dirname "$BG_PATH")"
xcrun swift "$WORKSPACE/Resources/make-bg.swift" "$BG_PATH" >/dev/null

# --- Stage ---
echo "  Staging contents..."
rm -rf "$STAGING"
mkdir -p "$STAGING/.background"
cp -R "$APP_BUNDLE" "$STAGING/$APP_NAME.app"
# /Library is the same path on every Mac (a symlink cannot expand ~); Finder asks for an admin password on drop.
ln -sf "/Library/Input Methods" "$STAGING/Input Methods"
cp "$BG_PATH" "$STAGING/.background/background.png"
[ -f "$ICON_PATH" ] && cp "$ICON_PATH" "$STAGING/.VolumeIcon.icns"

# --- Create raw DMG ---
echo "  Creating DMG..."
rm -f "$DMG_PATH"
STAGING_SIZE=$(($(du -sk "$STAGING" | awk '{print $1}') + 20000))

/usr/bin/hdiutil create \
    -fs HFS+ -format UDRW \
    -srcfolder "$STAGING" \
    -volname "$VOLUME_NAME" \
    -size "${STAGING_SIZE}k" \
    "$DMG_PATH" >/dev/null
rm -rf "$STAGING"
sleep 2 # ponytail: hdiutil create can still hold the image briefly; attach fails with EAGAIN without this

# --- Mount ---
echo "  Configuring window..."
# Detach any stale mounts first
/usr/bin/hdiutil info 2>/dev/null | grep -q "$VOLUME_NAME" && \
    /usr/bin/hdiutil detach -quiet "/Volumes/$VOLUME_NAME" 2>/dev/null || true

MOUNT_PLIST=$(/usr/bin/hdiutil attach "$DMG_PATH" -readwrite -noverify -noautoopen -plist 2>/dev/null)
MOUNT_POINT=$(echo "$MOUNT_PLIST" | python3 -c "
import plistlib, sys
d = plistlib.loads(sys.stdin.buffer.read())
for e in d.get('system-entities', []):
    mp = e.get('mount-point')
    if mp:
        print(mp)
        break
" 2>/dev/null)

if [ -z "$MOUNT_POINT" ]; then
    echo -e "${R}Failed to mount DMG${NC}"
    exit 1
fi
echo "  Mounted at: $MOUNT_POINT"

# Set volume icon
SetFile -a C "$MOUNT_POINT" 2>/dev/null || true

# AppleScript layout
/usr/bin/osascript >/dev/null 2>&1 <<EOS
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 150, 800, 550}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 96
        set background picture of opts to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to {120, 170}
        set position of item "Input Methods" of container window to {480, 170}
        close
    end tell
end tell
EOS

sleep 2

# --- Detach ---
/usr/bin/hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true

# --- Compress ---
echo "  Compressing..."
TEMP="${DMG_PATH}.tmp"
mv "$DMG_PATH" "$TEMP"
/usr/bin/hdiutil convert "$TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
rm -f "$TEMP"

echo ""
echo -e "${G}=== DMG created: $DMG_PATH ===${NC}"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "To install:"
echo "  1. open \"$DMG_PATH\""
echo "  2. Drag Khipro.app to the Input Methods folder (asks for your password), then log out and in"
echo "  3. Enable in System Settings > Keyboard > Input Sources"
