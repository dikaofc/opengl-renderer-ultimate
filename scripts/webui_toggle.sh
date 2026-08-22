#!/system/bin/sh
# ============================================================
# WebUI Quick Toggle — Run from any terminal or Termux shortcut
# ============================================================
# Usage:
#   webui_toggle.sh         — Toggle server on/off
#   webui_toggle.sh on      — Start server
#   webui_toggle.sh off     — Stop server
#   webui_toggle.sh status  — Show status + URL
# ============================================================

MODDIR="${0%/*}/.."
SERVER="$MODDIR/scripts/webui_server.sh"

case "${1:-toggle}" in
    on|start)
        "$SERVER" start
        ;;
    off|stop)
        "$SERVER" stop
        ;;
    status)
        STATUS=$("$SERVER" is-running 2>/dev/null)
        URL=$("$SERVER" url 2>/dev/null)
        if [ "$STATUS" = "running" ]; then
            echo "✅ WebUI Server: RUNNING"
            echo "📍 $URL"
            echo ""
            echo "Open this URL in any browser to access the WebUI."
        else
            echo "❌ WebUI Server: STOPPED"
            echo ""
            echo "Start with: sh ${0} on"
        fi
        ;;
    toggle|*)
        "$SERVER" toggle
        STATUS=$("$SERVER" is-running 2>/dev/null)
        URL=$("$SERVER" url 2>/dev/null)
        if [ "$STATUS" = "running" ]; then
            echo "✅ WebUI Server: ON"
            echo "📍 $URL"
        else
            echo "❌ WebUI Server: OFF"
        fi
        ;;
esac
