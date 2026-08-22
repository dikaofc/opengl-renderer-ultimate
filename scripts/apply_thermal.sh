#!/system/bin/sh
# ============================================================
# Thermal Management Script
# ============================================================

MODDIR="${0%/*}/.."
. "$MODDIR/scripts/functions.sh" 2>/dev/null

log "apply_thermal: Starting thermal management"

# ---- Cache config values ----
thermal_headroom="$(conf_get thermal_headroom 10000)"
thermal_mode="$(conf_get thermal_mode performance)"
polling="$(conf_get thermal_polling 2000)"
CPU_THROTTLE="$(conf_get cpu_throttle_temp 98000)"
GPU_THROTTLE="$(conf_get gpu_throttle_temp 98000)"

# ---- Single pass over all thermal zones ----
for tz in /sys/class/thermal/thermal_zone*; do
    [ -d "$tz" ] || continue

    type="$(cat "$tz/type" 2>/dev/null)"

    # Raise all trip point temperatures
    for tp in "$tz"/trip_point_*_temp; do
        [ -f "$tp" ] || continue
        cur="$(cat "$tp" 2>/dev/null)"
        if [ -n "$cur" ] && [ "$cur" -gt 0 ] 2>/dev/null; then
            write_sys "$tp" "$((cur + thermal_headroom))"
        fi
    done

    # Set polling interval
    write_sys "$tz/polling_interval" "$polling"

    # Disable thermal zone if performance mode
    if [ "$thermal_mode" = "performance" ]; then
        write_sys "$tz/mode" "disabled" 2>/dev/null
    elif [ "$thermal_mode" = "cool" ]; then
        write_sys "$tz/mode" "enabled" 2>/dev/null
    fi

    # CPU/GPU throttle trip points
    case "$type" in
        *cpu*|*CPU*)
            write_sys "$tz/trip_point_0_temp" "$CPU_THROTTLE" 2>/dev/null
            ;;
        *gpu*|*GPU*)
            write_sys "$tz/trip_point_0_temp" "$GPU_THROTTLE" 2>/dev/null
            ;;
    esac
done

# ---- Power Supply ----
write_sys "/sys/class/power_supply/battery/charging_control" "$(conf_get charging_control 1)" 2>/dev/null

log "apply_thermal: Thermal management complete (mode=$thermal_mode, headroom=$thermal_headroom)"
