#!/system/bin/sh
# ============================================================
# Profile Management Script
# ============================================================
# Usage:
#   apply_profile.sh save <name>       — Save current config as profile
#   apply_profile.sh load <name>       — Load and apply a profile
#   apply_profile.sh delete <name>     — Delete a profile
#   apply_profile.sh list              — List all profiles
#   apply_profile.sh rename <old> <new>— Rename a profile
#   apply_profile.sh export <name>     — Export profile to /sdcard
#   apply_profile.sh import <file>     — Import profile from file
#   apply_profile.sh current           — Show current active profile
#   apply_profile.sh set-active <name> — Set profile to auto-apply on boot
# ============================================================

MODDIR="${0%/*}/.."
. "$MODDIR/scripts/functions.sh" 2>/dev/null

PROFILES_DIR="$CONF_DIR/profiles"
ACTIVE_FILE="$CONF_DIR/active_profile"
AUTO_APPLY_FILE="$CONF_DIR/auto_apply_profile"

mkdir -p "$PROFILES_DIR" 2>/dev/null

# ---- Save current config as profile ----
cmd_save() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "ERROR: Profile name required"
        echo "Usage: $0 save <name>"
        exit 1
    fi

    # Sanitize name — only alphanumeric, dash, underscore
    name=$(echo "$name" | tr -cd 'a-zA-Z0-9_-')
    if [ -z "$name" ]; then
        echo "ERROR: Invalid profile name"
        exit 1
    fi

    local profile_dir="$PROFILES_DIR/$name"
    mkdir -p "$profile_dir" 2>/dev/null

    # Save main config
    if [ -f "$CONF" ]; then
        cp "$CONF" "$profile_dir/config.conf"
    fi

    # Save current system properties snapshot
    cat > "$profile_dir/system.prop" << PROPSPROP
# System Properties Snapshot — $(date '+%Y-%m-%d %H:%M:%S')
debug.hwui.renderer=$(getprop debug.hwui.renderer 2>/dev/null)
debug.renderengine.backend=$(getprop debug.renderengine.backend 2>/dev/null)
debug.hwui.use_hint_manager=$(getprop debug.hwui.use_hint_manager 2>/dev/null)
debug.hwui.target_cpu_time_percent=$(getprop debug.hwui.target_cpu_time_percent 2>/dev/null)
debug.hwui.frame_pacing=$(getprop debug.hwui.frame_pacing 2>/dev/null)
debug.hwui.texture_cache_size=$(getprop debug.hwui.texture_cache_size 2>/dev/null)
debug.hwui.layer_cache_size=$(getprop debug.hwui.layer_cache_size 2>/dev/null)
debug.hwui.use_multi_threaded_pipeline=$(getprop debug.hwui.use_multi_threaded_pipeline 2>/dev/null)
debug.egl.force_msaa=$(getprop debug.egl.force_msaa 2>/dev/null)
debug.egl.swapinterval=$(getprop debug.egl.swapinterval 2>/dev/null)
window_animation_scale=$(getprop window_animation_scale 2>/dev/null)
transition_animation_scale=$(getprop transition_animation_scale 2>/dev/null)
animator_duration_scale=$(getprop animator_duration_scale 2>/dev/null)
PROPSPROP

    # Save CPU state snapshot
    cat > "$profile_dir/cpu_snapshot.sh" << CPUEOF
#!/system/bin/sh
# CPU State Snapshot — $(date '+%Y-%m-%d %H:%M:%S')
CPUEOF

    local cpu_count=$(ls -d /sys/devices/system/cpu/cpu[0-9]* 2>/dev/null | wc -l)
    for i in $(seq 0 $((cpu_count - 1))); do
        local cpu="/sys/devices/system/cpu/cpu$i/cpufreq"
        [ -d "$cpu" ] || continue
        local gov=$(cat "$cpu/scaling_governor" 2>/dev/null)
        local max=$(cat "$cpu/scaling_max_freq" 2>/dev/null)
        local min=$(cat "$cpu/scaling_min_freq" 2>/dev/null)
        local cur=$(cat "$cpu/scaling_cur_freq" 2>/dev/null)
        echo "cpu$i: gov=$gov max=$max min=$min cur=$cur" >> "$profile_dir/cpu_snapshot.sh"
    done

    # Save GPU state snapshot
    cat > "$profile_dir/gpu_snapshot.sh" << GPUEOF
#!/system/bin/sh
# GPU State Snapshot — $(date '+%Y-%m-%d %H:%M:%S')
GPUEOF

    local kgsl="/sys/class/kgsl/kgsl-3d0"
    if [ -d "$kgsl" ]; then
        local gpu_gov=$(cat "$kgsl/devfreq/governor" 2>/dev/null)
        local gpu_clk=$(cat "$kgsl/gpuclk" 2>/dev/null)
        local gpu_max=$(cat "$kgsl/max_gpuclk" 2>/dev/null)
        echo "adreno: governor=$gpu_gov current=$gpu_clk max=$gpu_max" >> "$profile_dir/gpu_snapshot.sh"
    fi

    # Save RAM state snapshot
    cat > "$profile_dir/ram_snapshot.sh" << RAMEOF
#!/system/bin/sh
# RAM State Snapshot — $(date '+%Y-%m-%d %H:%M:%S')
RAMEOF
    echo "swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null)" >> "$profile_dir/ram_snapshot.sh"
    echo "dirty_ratio=$(cat /proc/sys/vm/dirty_ratio 2>/dev/null)" >> "$profile_dir/ram_snapshot.sh"
    echo "vfs_cache_pressure=$(cat /proc/sys/vm/vfs_cache_pressure 2>/dev/null)" >> "$profile_dir/ram_snapshot.sh"

    # Save network state snapshot
    cat > "$profile_dir/net_snapshot.sh" << NETEOF
#!/bin/sh
# Network State Snapshot — $(date '+%Y-%m-%d %H:%M:%S')
NETEOF
    echo "tcp_congestion=$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null)" >> "$profile_dir/net_snapshot.sh"
    echo "qdisc=$(cat /proc/sys/net/core/default_qdisc 2>/dev/null)" >> "$profile_dir/net_snapshot.sh"

    # Save thermal state
    cat > "$profile_dir/thermal_snapshot.sh" << THEEOF
#!/bin/sh
# Thermal State Snapshot — $(date '+%Y-%m-%d %H:%M:%S')
THEEOF
    for tz in /sys/class/thermal/thermal_zone*; do
        [ -d "$tz" ] || continue
        local tztype=$(cat "$tz/type" 2>/dev/null)
        local tztemp=$(cat "$tz/temp" 2>/dev/null)
        echo "$tztype: ${tztemp}m°C" >> "$profile_dir/thermal_snapshot.sh"
    done

    # Metadata
    cat > "$profile_dir/meta.conf" << METAEOF
name=$name
created=$(date '+%Y-%m-%d %H:%M:%S')
device=$(getprop ro.product.model 2>/dev/null)
android=$(getprop ro.build.version.release 2>/dev/null)
sdk=$(getprop ro.build.version.sdk 2>/dev/null)
gpu=$(getprop ro.hardware.egl 2>/dev/null)
METAEOF

    chmod -R 0644 "$profile_dir"/* 2>/dev/null
    echo "OK: Profile '$name' saved"
}

# ---- Load and apply a profile ----
cmd_load() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "ERROR: Profile name required"
        echo "Usage: $0 load <name>"
        exit 1
    fi

    local profile_dir="$PROFILES_DIR/$name"
    if [ ! -d "$profile_dir" ]; then
        echo "ERROR: Profile '$name' not found"
        exit 1
    fi

    # Apply system properties from profile
    if [ -f "$profile_dir/system.prop" ]; then
        while IFS='=' read -r prop val; do
            case "$prop" in \#*|"") continue ;; esac
            prop=$(echo "$prop" | tr -d ' ')
            val=$(echo "$val" | tr -d ' ')
            setprop "$prop" "$val" 2>/dev/null
            echo "[OK] $prop = $val"
        done < "$profile_dir/system.prop"
    fi

    # Apply config overrides
    if [ -f "$profile_dir/config.conf" ]; then
        cp "$profile_dir/config.conf" "$CONF"
        apply_config "$CONF"
    fi

    # Set as active
    echo "$name" > "$ACTIVE_FILE"
    echo "OK: Profile '$name' loaded and applied"
}

# ---- Delete a profile ----
cmd_delete() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "ERROR: Profile name required"
        exit 1
    fi

    local profile_dir="$PROFILES_DIR/$name"
    if [ ! -d "$profile_dir" ]; then
        echo "ERROR: Profile '$name' not found"
        exit 1
    fi

    rm -rf "$profile_dir"
    if [ "$(cat "$ACTIVE_FILE" 2>/dev/null)" = "$name" ]; then
        rm -f "$ACTIVE_FILE"
    fi
    echo "OK: Profile '$name' deleted"
}

# ---- Rename a profile ----
cmd_rename() {
    local old="$1"
    local new="$2"
    if [ -z "$old" ] || [ -z "$new" ]; then
        echo "ERROR: Usage: $0 rename <old> <new>"
        exit 1
    fi

    new=$(echo "$new" | tr -cd 'a-zA-Z0-9_-')
    if [ ! -d "$PROFILES_DIR/$old" ]; then
        echo "ERROR: Profile '$old' not found"
        exit 1
    fi
    if [ -d "$PROFILES_DIR/$new" ]; then
        echo "ERROR: Profile '$new' already exists"
        exit 1
    fi

    mv "$PROFILES_DIR/$old" "$PROFILES_DIR/$new"
    # Update name in meta
    sed -i "s/^name=.*/name=$new/" "$PROFILES_DIR/$new/meta.conf" 2>/dev/null

    if [ "$(cat "$ACTIVE_FILE" 2>/dev/null)" = "$old" ]; then
        echo "$new" > "$ACTIVE_FILE"
    fi
    echo "OK: Renamed '$old' → '$new'"
}

# ---- List all profiles ----
cmd_list() {
    echo "=== Profiles ==="
    echo ""

    local active=$(cat "$ACTIVE_FILE" 2>/dev/null)
    local count=0

    for dir in "$PROFILES_DIR"/*/; do
        [ -d "$dir" ] || continue
        local pname=$(basename "$dir")
        local meta="$dir/meta.conf"
        local created="-"
        local device="-"
        local marker=""

        if [ "$pname" = "$active" ]; then
            marker=" ★ ACTIVE"
        fi

        if [ -f "$meta" ]; then
            created=$(grep "^created=" "$meta" 2>/dev/null | cut -d'=' -f2)
            device=$(grep "^device=" "$meta" 2>/dev/null | cut -d'=' -f2)
        fi

        echo "  $pname$marker"
        echo "    Created : $created"
        echo "    Device  : $device"
        echo ""
        count=$((count + 1))
    done

    if [ "$count" -eq 0 ]; then
        echo "  No profiles saved yet"
    fi

    echo "Total: $count profile(s)"
    echo ""

    local auto=$(cat "$AUTO_APPLY_FILE" 2>/dev/null)
    if [ -n "$auto" ]; then
        echo "Auto-apply on boot: $auto"
    fi
}

# ---- Export profile to /sdcard ----
cmd_export() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "ERROR: Profile name required"
        exit 1
    fi

    local profile_dir="$PROFILES_DIR/$name"
    if [ ! -d "$profile_dir" ]; then
        echo "ERROR: Profile '$name' not found"
        exit 1
    fi

    local export_dir="/sdcard/OpenGLProfiles"
    mkdir -p "$export_dir" 2>/dev/null
    local export_file="$export_dir/${name}_$(date +%Y%m%d_%H%M%S).tar.gz"

    # Create tarball
    tar -czf "$export_file" -C "$PROFILES_DIR" "$name" 2>/dev/null

    if [ -f "$export_file" ]; then
        echo "OK: Exported to $export_file"
        echo "Size: $(du -h "$export_file" | awk '{print $1}')"
    else
        echo "ERROR: Export failed"
    fi
}

# ---- Import profile from file ----
cmd_import() {
    local file="$1"
    if [ -z "$file" ]; then
        echo "ERROR: File path required"
        echo "Usage: $0 import <path.tar.gz>"
        exit 1
    fi

    if [ ! -f "$file" ]; then
        echo "ERROR: File '$file' not found"
        exit 1
    fi

    # Extract to profiles dir
    tar -xzf "$file" -C "$PROFILES_DIR" 2>/dev/null

    # Verify extraction
    local imported=0
    for dir in "$PROFILES_DIR"/*/; do
        [ -d "$dir" ] || continue
        if [ -f "$dir/config.conf" ]; then
            local pname=$(basename "$dir")
            echo "OK: Imported profile '$pname'"
            imported=$((imported + 1))
        fi
    done

    if [ "$imported" -eq 0 ]; then
        echo "ERROR: No valid profiles found in archive"
    fi
}

# ---- Show current active profile ----
cmd_current() {
    local active=$(cat "$ACTIVE_FILE" 2>/dev/null)
    if [ -z "$active" ]; then
        echo "No active profile"
    else
        echo "Active profile: $active"
        if [ -f "$PROFILES_DIR/$active/meta.conf" ]; then
            echo "Created: $(grep '^created=' "$PROFILES_DIR/$active/meta.conf" | cut -d'=' -f2)"
            echo "Device:  $(grep '^device=' "$PROFILES_DIR/$active/meta.conf" | cut -d'=' -f2)"
        fi
    fi
}

# ---- Set auto-apply profile on boot ----
cmd_set_active() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "ERROR: Profile name required"
        exit 1
    fi

    if [ "$name" = "none" ]; then
        rm -f "$AUTO_APPLY_FILE"
        echo "OK: Auto-apply disabled"
        return
    fi

    if [ ! -d "$PROFILES_DIR/$name" ]; then
        echo "ERROR: Profile '$name' not found"
        exit 1
    fi

    echo "$name" > "$AUTO_APPLY_FILE"
    echo "OK: Profile '$name' will auto-apply on boot"
}

# ---- Duplicate a profile ----
cmd_duplicate() {
    local src="$1"
    local dst="$2"
    if [ -z "$src" ] || [ -z "$dst" ]; then
        echo "ERROR: Usage: $0 duplicate <source> <destination>"
        exit 1
    fi

    dst=$(echo "$dst" | tr -cd 'a-zA-Z0-9_-')
    if [ ! -d "$PROFILES_DIR/$src" ]; then
        echo "ERROR: Profile '$src' not found"
        exit 1
    fi
    if [ -d "$PROFILES_DIR/$dst" ]; then
        echo "ERROR: Profile '$dst' already exists"
        exit 1
    fi

    cp -r "$PROFILES_DIR/$src" "$PROFILES_DIR/$dst"
    sed -i "s/^name=.*/name=$dst/" "$PROFILES_DIR/$dst/meta.conf" 2>/dev/null
    echo "OK: Duplicated '$src' → '$dst'"
}

# ---- Main dispatch ----
case "$1" in
    save)       cmd_save "$2" ;;
    load)       cmd_load "$2" ;;
    delete)     cmd_delete "$2" ;;
    list)       cmd_list ;;
    rename)     cmd_rename "$2" "$3" ;;
    export)     cmd_export "$2" ;;
    import)     cmd_import "$2" ;;
    current)    cmd_current ;;
    set-active) cmd_set_active "$2" ;;
    duplicate)  cmd_duplicate "$2" "$3" ;;
    *)
        echo "OpenGL Renderer Ultimate — Profile Manager"
        echo ""
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  save <name>             Save current config as profile"
        echo "  load <name>             Load and apply a profile"
        echo "  delete <name>           Delete a profile"
        echo "  list                    List all profiles"
        echo "  rename <old> <new>      Rename a profile"
        echo "  duplicate <src> <dst>   Duplicate a profile"
        echo "  export <name>           Export to /sdcard/OpenGLProfiles/"
        echo "  import <file.tar.gz>    Import from file"
        echo "  current                 Show active profile"
        echo "  set-active <name|none>  Auto-apply on boot"
        ;;
esac
