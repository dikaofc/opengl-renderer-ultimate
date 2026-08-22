#!/system/bin/sh
# ============================================================
# Check Update Script — OpenGL Renderer Ultimate
# ============================================================
# Usage:
#   check_update.sh              — Check for updates
#   check_update.sh force        — Force download and install update
#   check_update.sh auto         — Check silently, return 0 if update available
# ============================================================

MODDIR="${0%/*}/.."
. "$MODDIR/scripts/functions.sh" 2>/dev/null

REPO="dikaofc/opengl-renderer-ultimate"
UPDATE_JSON_URL="https://raw.githubusercontent.com/$REPO/main/update.json"
RELEASE_URL="https://github.com/$REPO/releases"
DOWNLOAD_DIR="/sdcard/Download"

# ---- Get Current Version ----
get_current_version() {
    local ver=$(grep "^version=" "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2)
    echo "${ver:-0.0.0}"
}

get_current_versioncode() {
    local code=$(grep "^versionCode=" "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2)
    echo "${code:-0}"
}

# ---- Compare Versions ----
# Returns: 0 if same, 1 if $1 > $2, 2 if $1 < $2
version_compare() {
    local v1="$1"
    local v2="$2"

    # Strip leading v
    v1=$(echo "$v1" | sed 's/^v//')
    v2=$(echo "$v2" | sed 's/^v//')

    if [ "$v1" = "$v2" ]; then
        echo 0
        return
    fi

    local IFS='.'
    local i v1_parts="" v2_parts=""

    for i in $(seq 1 3); do
        local a=$(echo "$v1" | cut -d. -f$i)
        local b=$(echo "$v2" | cut -d. -f$i)
        [ -z "$a" ] && a=0
        [ -z "$b" ] && b=0

        if [ "$a" -gt "$b" ] 2>/dev/null; then
            echo 1
            return
        fi
        if [ "$a" -lt "$b" ] 2>/dev/null; then
            echo 2
            return
        fi
    done

    echo 0
}

# ---- Check for Updates ----
check_update() {
    local current_ver=$(get_current_version)
    local current_code=$(get_current_versioncode)

    log "check_update: Current version: $current_ver (code: $current_code)"

    # Fetch update.json
    local json=""
    if command -v curl >/dev/null 2>&1; then
        json=$(curl -sL --connect-timeout 10 --max-time 15 "$UPDATE_JSON_URL" 2>/dev/null)
    elif command -v wget >/dev/null 2>&1; then
        json=$(wget -qO- --timeout=15 "$UPDATE_JSON_URL" 2>/dev/null)
    fi

    if [ -z "$json" ] || ! echo "$json" | grep -q "version"; then
        log "check_update: Failed to fetch update.json"
        echo "ERROR: Could not check for updates (network error)"
        return 1
    fi

    # Parse JSON (simple grep/sed since we don't have jq)
    local latest_ver=$(echo "$json" | grep '"version"' | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//')
    local latest_code=$(echo "$json" | grep '"versionCode"' | head -1 | sed 's/.*"versionCode"[[:space:]]*:[[:space:]]*//' | sed 's/[^0-9].*//')
    local zip_url=$(echo "$json" | grep '"zipUrl"' | head -1 | sed 's/.*"zipUrl"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//')
    local changelog_url=$(echo "$json" | grep '"changelog"' | head -1 | sed 's/.*"changelog"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//')
    local note=$(echo "$json" | grep '"note"' | head -1 | sed 's/.*"note"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//')

    log "check_update: Latest version: $latest_ver (code: $latest_code)"

    # Compare version codes (more reliable)
    local has_update=0
    if [ -n "$latest_code" ] && [ -n "$current_code" ] && [ "$latest_code" -gt "$current_code" ] 2>/dev/null; then
        has_update=1
    elif [ -n "$latest_ver" ]; then
        local cmp=$(version_compare "$latest_ver" "$current_ver")
        [ "$cmp" = "1" ] && has_update=1
    fi

    if [ "$has_update" = "1" ]; then
        echo ""
        echo "============================================================"
        echo " UPDATE AVAILABLE"
        echo "============================================================"
        echo ""
        echo "  Current : $current_ver (code: $current_code)"
        echo "  Latest  : $latest_ver (code: $latest_code)"
        echo ""
        [ -n "$note" ] && echo "  Note    : $note"
        echo ""
        echo "  Download : $zip_url"
        echo "  Changelog: $changelog_url"
        echo ""
        echo "============================================================"
        echo ""
        echo "To update:"
        echo "  1. Download the ZIP from the URL above"
        echo "  2. Open KernelSU/Magisk → Modules → Install from storage"
        echo "  3. Select the downloaded ZIP → Flash → Reboot"
        echo ""
        echo "Or run: $0 force"
        echo ""

        # Auto-download if force mode
        return 0
    else
        echo ""
        echo "============================================================"
        echo " NO UPDATE AVAILABLE"
        echo "============================================================"
        echo ""
        echo "  Current : $current_ver (code: $current_code)"
        echo "  Latest  : $latest_ver (code: $latest_code)"
        echo ""
        echo "  You are running the latest version!"
        echo ""
        echo "============================================================"
        return 1
    fi
}

# ---- Force Download and Install ----
force_update() {
    local current_ver=$(get_current_version)
    local current_code=$(get_current_versioncode)

    echo "Checking for updates..."

    local json=""
    if command -v curl >/dev/null 2>&1; then
        json=$(curl -sL --connect-timeout 10 --max-time 15 "$UPDATE_JSON_URL" 2>/dev/null)
    elif command -v wget >/dev/null 2>&1; then
        json=$(wget -qO- --timeout=15 "$UPDATE_JSON_URL" 2>/dev/null)
    fi

    if [ -z "$json" ] || ! echo "$json" | grep -q "version"; then
        echo "ERROR: Could not check for updates"
        return 1
    fi

    local latest_ver=$(echo "$json" | grep '"version"' | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//')
    local latest_code=$(echo "$json" | grep '"versionCode"' | head -1 | sed 's/.*"versionCode"[[:space:]]*:[[:space:]]*//' | sed 's/[^0-9].*//')
    local zip_url=$(echo "$json" | grep '"zipUrl"' | head -1 | sed 's/.*"zipUrl"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//')

    local has_update=0
    if [ -n "$latest_code" ] && [ "$current_code" -lt "$latest_code" ] 2>/dev/null; then
        has_update=1
    fi

    if [ "$has_update" = "0" ]; then
        echo "Already on latest version ($current_ver)"
        return 1
    fi

    echo "Update found: $current_ver -> $latest_ver"
    echo ""

    # Download ZIP
    local zip_file="$DOWNLOAD_DIR/OpenGL_Renderer_Ultimate_${latest_ver}_Flashable.zip"
    echo "Downloading to $zip_file..."

    if command -v curl >/dev/null 2>&1; then
        curl -L --progress-bar -o "$zip_file" "$zip_url" 2>&1
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$zip_file" "$zip_url" 2>&1
    else
        echo "ERROR: Neither curl nor wget available"
        return 1
    fi

    if [ ! -f "$zip_file" ]; then
        echo "ERROR: Download failed"
        return 1
    fi

    local file_size=$(ls -lh "$zip_file" | awk '{print $5}')
    echo ""
    echo "Downloaded: $zip_file ($file_size)"
    echo ""
    echo "To install:"
    echo "  1. Open KernelSU/Magisk → Modules → Install from storage"
    echo "  2. Select: $zip_file"
    echo "  3. Flash → Reboot"
    echo ""
    echo "Or install via terminal:"
    echo "  su -c 'ksud module install $zip_file'"
    echo ""
}

# ---- Silent Check (for scripting) ----
silent_check() {
    local current_code=$(get_current_versioncode)

    local json=""
    if command -v curl >/dev/null 2>&1; then
        json=$(curl -sL --connect-timeout 10 --max-time 15 "$UPDATE_JSON_URL" 2>/dev/null)
    elif command -v wget >/dev/null 2>&1; then
        json=$(wget -qO- --timeout=15 "$UPDATE_JSON_URL" 2>/dev/null)
    fi

    if [ -z "$json" ]; then
        return 1
    fi

    local latest_code=$(echo "$json" | grep '"versionCode"' | head -1 | sed 's/.*"versionCode"[[:space:]]*:[[:space:]]*//' | sed 's/[^0-9].*//')

    if [ -n "$latest_code" ] && [ "$latest_code" -gt "$current_code" ] 2>/dev/null; then
        local latest_ver=$(echo "$json" | grep '"version"' | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//')
        echo "$latest_ver"
        return 0
    fi

    return 1
}

# ---- Main Dispatch ----
case "$1" in
    force)  force_update ;;
    auto)   silent_check ;;
    *)      check_update ;;
esac
