#!/system/bin/sh
# ============================================================
# Game Mode Daemon — Auto-Detect Foreground Game
# ============================================================
# Runs in background, monitors foreground activity
# Automatically applies game preset when a game is detected
# Automatically reverts when game is closed
#
# Usage:
#   gamemode_daemon.sh start   — Start daemon (background)
#   gamemode_daemon.sh stop    — Stop daemon
#   gamemode_daemon.sh status  — Check if running
# ============================================================

MODDIR="${0%/*}/.."
. "$MODDIR/scripts/functions.sh" 2>/dev/null

PID_FILE="$CONF_DIR/gamemode_daemon.pid"
LOG_FILE="$CONF_DIR/logs/gamemode_daemon.log"
CHECK_INTERVAL=3  # seconds between checks

# Known game packages
GAME_PKGS="
com.mobile.legends
com.tencent.lolm
com.tencent.KiHan
com.tencent.tmgp.sgame
com.netease.ma
com.tencent.ig
com.pubg.krmobile
com.pubg.imobile
com.dts.freefireth
com.garena.game.codm
com.activision.callofduty.shooter
com.epicgames.fortnite
com.netease.g93na
com.miHoYo.GenshinImpact
com.miHoYo.hkrpg
com.HoYoverse.Nap
com.kurogame.gplay.punishing
com.gameloft.android.ANMP.GloftA9HM
com.roblox.client
com.mojang.minecraftpe
com.supercell.clashofclans
com.supercell.clashroyale
com.king.candycrushsaga
com.nianticlabs.pokemongo
com.ea.gp.fifamobile
com.miniclip.eightballpool
"

# Genre detection
get_genre() {
    case "$1" in
        *mobile.legends*|*tencent.lolm*|*tencent.KiHan*|*tencent.tmgp.sgame*|*netease.ma*)
            echo "moba" ;;
        *tencent.ig*|*pubg*|*freefire*|*codm*|*callofduty*|*fortnite*|*netease.g93na*)
            echo "battle_royale" ;;
        *miHoYo*|*HoYoverse*|*kurogame*)
            echo "open_world" ;;
        *GloftA9*|*asphalt*)
            echo "racing" ;;
        *roblox*|*minecraftpe*|*clashofclans*|*clashroyale*|*candycrush*|*pokemon*|*fifa*|*eightball*)
            echo "casual" ;;
        *)
            echo "battle_royale" ;;
    esac
}

# Check if package is a known game
is_game() {
    local pkg="$1"
    echo "$GAME_PKGS" | grep -q "$pkg" 2>/dev/null

    # Also check custom games file
    local custom_file="$CONF_DIR/custom_games.conf"
    if [ -f "$custom_file" ] && grep -q "$pkg" "$custom_file" 2>/dev/null; then
        return 0
    fi

    return $?
}

# Get foreground package
get_foreground_pkg() {
    # Method 1: dumpsys
    local pkg=$(dumpsys activity activities 2>/dev/null | grep -E "mResumedActivity|topResumedActivity" | head -1 | sed 's/.*u0 //' | sed 's/\/.*//' | tr -d ' ')

    if [ -z "$pkg" ]; then
        # Method 2: dumpsys window
        pkg=$(dumpsys window 2>/dev/null | grep -E "mCurrentFocus|mFocusedApp" | head -1 | sed 's/.*{[^ ]* [^ ]* //' | sed 's/\/.*//' | tr -d '}')
    fi

    echo "$pkg"
}

# Daemon main loop
daemon_loop() {
    log "gamemode_daemon: Started (PID: $$)"
    echo "$$" > "$PID_FILE"

    local last_pkg=""
    local game_active=0

    while true; do
        local fg_pkg=$(get_foreground_pkg)

        if [ -n "$fg_pkg" ] && [ "$fg_pkg" != "$last_pkg" ]; then
            if is_game "$fg_pkg"; then
                if [ "$game_active" = "0" ]; then
                    local genre=$(get_genre "$fg_pkg")
                    log "gamemode_daemon: Game detected: $fg_pkg ($genre)"

                    # Apply game preset
                    "$MODDIR/scripts/apply_gamemode.sh" apply "$fg_pkg" >/dev/null 2>&1

                    # Set game mode as active
                    echo "$fg_pkg" > "$CONF_DIR/gamemode_active"
                    game_active=1
                fi
            else
                if [ "$game_active" = "1" ]; then
                    log "gamemode_daemon: Game closed, reverting settings"
                    "$MODDIR/scripts/apply_gamemode.sh" off >/dev/null 2>&1
                    game_active=0
                fi
            fi
            last_pkg="$fg_pkg"
        fi

        sleep "$CHECK_INTERVAL"
    done
}

# Start daemon
cmd_start() {
    # Check if already running
    if [ -f "$PID_FILE" ]; then
        local old_pid=$(cat "$PID_FILE" 2>/dev/null)
        if kill -0 "$old_pid" 2>/dev/null; then
            echo "Daemon already running (PID: $old_pid)"
            return
        fi
        rm -f "$PID_FILE"
    fi

    echo "Starting Game Mode Daemon..."
    daemon_loop &
    local daemon_pid=$!
    echo "$daemon_pid" > "$PID_FILE"
    echo "Daemon started (PID: $daemon_pid)"
    echo "Monitoring foreground app every ${CHECK_INTERVAL}s"
    echo "Logs: $LOG_FILE"
}

# Stop daemon
cmd_stop() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Daemon not running"
        return
    fi

    local pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
        rm -f "$PID_FILE"
        echo "Daemon stopped (PID: $pid)"

        # Revert game mode if active
        if [ -f "$CONF_DIR/gamemode_active" ]; then
            "$MODDIR/scripts/apply_gamemode.sh" off >/dev/null 2>&1
            echo "Game mode reverted"
        fi
    else
        rm -f "$PID_FILE"
        echo "Daemon was not running (stale PID)"
    fi
}

# Status
cmd_status() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if kill -0 "$pid" 2>/dev/null; then
            echo "Daemon: RUNNING (PID: $pid)"
        else
            echo "Daemon: NOT RUNNING (stale PID: $pid)"
        fi
    else
        echo "Daemon: NOT RUNNING"
    fi

    if [ -f "$CONF_DIR/gamemode_active" ]; then
        local game=$(head -1 "$CONF_DIR/gamemode_active" 2>/dev/null)
        echo "Active game: $game"
    else
        echo "Active game: none"
    fi

    echo "Check interval: ${CHECK_INTERVAL}s"
    echo "Log: $LOG_FILE"
}

# Main dispatch
case "$1" in
    start)  cmd_start ;;
    stop)   cmd_stop ;;
    status) cmd_status ;;
    *)
        echo "Game Mode Daemon"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  start   Start auto-detect daemon"
        echo "  stop    Stop daemon"
        echo "  status  Check daemon status"
        ;;
esac
