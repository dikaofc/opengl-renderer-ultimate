#!/system/bin/sh
# ============================================================
# Quick Toggle — Game Mode On/Off
# ============================================================
# Toggle game mode from terminal or quick settings tile
#
# Usage:
#   quick_toggle.sh          — Toggle game mode
#   quick_toggle.sh on       — Force enable
#   quick_toggle.sh off      — Force disable
#   quick_toggle.sh status   — Show status
# ============================================================

MODDIR="${0%/*}/.."
. "$MODDIR/scripts/functions.sh" 2>/dev/null

STATUS_FILE="$CONF_DIR/gamemode_active"

get_status() {
    if [ -f "$STATUS_FILE" ]; then
        echo "ON"
    else
        echo "OFF"
    fi
}

toggle() {
    local current=$(get_status)

    if [ "$current" = "ON" ]; then
        "$MODDIR/scripts/apply_gamemode.sh" off >/dev/null 2>&1
        echo "Game Mode: OFF"
    else
        # Detect current foreground game
        local pkg=$("$MODDIR/scripts/apply_gamemode.sh" detect 2>/dev/null)
        if [ -n "$pkg" ]; then
            "$MODDIR/scripts/apply_gamemode.sh" apply "$pkg" >/dev/null 2>&1
            echo "Game Mode: ON ($pkg)"
        else
            # Default to battle royale preset
            "$MODDIR/scripts/apply_gamemode.sh" apply com.custom.auto >/dev/null 2>&1
            echo "Game Mode: ON (default preset)"
        fi
    fi
}

enable() {
    "$MODDIR/scripts/apply_gamemode.sh" off >/dev/null 2>&1
    local pkg=$("$MODDIR/scripts/apply_gamemode.sh" detect 2>/dev/null)
    if [ -n "$pkg" ]; then
        "$MODDIR/scripts/apply_gamemode.sh" apply "$pkg" >/dev/null 2>&1
        echo "Game Mode: ON ($pkg)"
    else
        echo "No game detected. Start a game first."
    fi
}

disable() {
    "$MODDIR/scripts/apply_gamemode.sh" off >/dev/null 2>&1
    echo "Game Mode: OFF"
}

case "$1" in
    on)     enable ;;
    off)    disable ;;
    status) echo "Game Mode: $(get_status)" ;;
    *)      toggle ;;
esac
