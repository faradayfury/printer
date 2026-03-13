#!/bin/sh
#
# Install a LaunchDaemon that auto-uploads firmware when the
# HP LaserJet P1007 is connected via USB.
#
# Usage: sudo ./install-hotplug.sh
#

set -e

FIRMWARE="/usr/local/share/foo2xqx/firmware/sihpP1005.dl"
PLIST_NAME="com.foo2xqx.firmware-upload"
PLIST_PATH="/Library/LaunchDaemons/$PLIST_NAME.plist"
SCRIPT_PATH="/usr/local/bin/hp-p1007-firmware-upload"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run with sudo."
    exit 1
fi

if [ ! -f "$FIRMWARE" ]; then
    echo "ERROR: Firmware not found at $FIRMWARE"
    echo "Run install.sh first."
    exit 1
fi

# Create the firmware upload script
cat > "$SCRIPT_PATH" << 'SCRIPT'
#!/bin/sh
#
# Upload firmware to HP LaserJet P1007 when it appears on USB.
# Called by launchd when USB device matches.
#
LOG="/tmp/hp-p1007-firmware.log"
FIRMWARE="/usr/local/share/foo2xqx/firmware/sihpP1005.dl"

echo "$(date): HP LaserJet P1007 detected, uploading firmware..." >> "$LOG"

# Wait briefly for the USB device to be fully ready
sleep 2

# Try to send firmware via CUPS
if command -v lp >/dev/null 2>&1; then
    lp -oraw "$FIRMWARE" >> "$LOG" 2>&1
    echo "$(date): Firmware upload complete (exit code: $?)" >> "$LOG"
else
    echo "$(date): ERROR: lp command not found" >> "$LOG"
fi
SCRIPT

chmod 755 "$SCRIPT_PATH"

# Create the LaunchDaemon plist
# This watches for any USB device change and runs the firmware upload
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_PATH</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>/Library/Printers</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF

chmod 644 "$PLIST_PATH"

# Load the daemon
if ! launchctl load "$PLIST_PATH" 2>&1; then
    echo "WARNING: Failed to load LaunchDaemon. You may need to reboot or load it manually:"
    echo "  sudo launchctl load $PLIST_PATH"
fi

echo "Firmware auto-upload daemon installed."
echo "  Script: $SCRIPT_PATH"
echo "  Daemon: $PLIST_PATH"
echo ""
echo "The firmware will be uploaded when the printer is detected."
echo "You can also manually upload at any time with:"
echo "  lp -oraw $FIRMWARE"
