#!/system/bin/sh
# ============================================================
# OpenGL Renderer Ultimate — Installer
# ============================================================

SKIPUNZIP=0

# Print banner
ui_print "╔══════════════════════════════════════╗"
ui_print "║  OpenGL Renderer Ultimate v3.2.14    ║"
ui_print "║  Ultimate Performance Module         ║"
ui_print "╚══════════════════════════════════════╝"
ui_print ""

# Check Android version
API=$(getprop ro.build.version.sdk 2>/dev/null)
ui_print "- Android SDK: $API"
if [ "$API" -lt 24 ]; then
    ui_print "! Requires Android 7.0+ (SDK 24+)"
    abort "! Aborting"
fi

# Extract module files
ui_print "- Extracting module files..."
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm_recursive "$MODPATH/scripts" 0 0 0755 0755
set_perm_recursive "$MODPATH/webroot" 0 0 0755 0644

# Make all .sh files executable
find "$MODPATH" -name "*.sh" -exec chmod 0755 {} \; 2>/dev/null

# Ensure webroot is readable by web server
chmod -R 0755 "$MODPATH/webroot" 2>/dev/null
mkdir -p "$MODPATH/webroot/cgi-bin"
chmod 0755 "$MODPATH/webroot/cgi-bin" 2>/dev/null

# Create data config directory
mkdir -p /data/local/opengl_renderer
chmod 0755 /data/local/opengl_renderer

# Create default config if not exists
if [ ! -f /data/local/opengl_renderer/config.conf ]; then
    cp "$MODPATH/scripts/default.conf" /data/local/opengl_renderer/config.conf 2>/dev/null
    chmod 0644 /data/local/opengl_renderer/config.conf
    ui_print "- Default config created"
fi

# Create profiles directory
mkdir -p /data/local/opengl_renderer/profiles
chmod 0755 /data/local/opengl_renderer/profiles

# Create log directory
mkdir -p /data/local/opengl_renderer/logs
chmod 0755 /data/local/opengl_renderer/logs

# Create export directory on sdcard
mkdir -p /sdcard/OpenGLProfiles 2>/dev/null
ui_print "- Profiles directory ready"

ui_print ""
ui_print "- Installation complete!"
ui_print "- Reboot to apply all settings"
ui_print "- WebUI available in KernelSU Manager"
ui_print ""
