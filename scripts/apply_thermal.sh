#!/system/bin/sh
# ============================================================
# Thermal Management Script
# ============================================================

MODDIR="${0%/*}/.."
. "$MODDIR/scripts/functions.sh" 2>/dev/null

log "apply_thermal: Starting thermal management"

# ---- Thermal Zone Trip Points ----
# Raise thermal trip points for maximum performance headroom
thermal_headroom="$(conf_get thermal_headroom 10000)"

for tz in /sys/class/thermal/thermal_zone*; do
    [ -d "$tz" ] || continue

    type="$(cat "$tz/type" 2>/dev/null)"
    log "apply_thermal: Processing $type"

    # Raise all trip point temperatures
    for tp in "$tz"/trip_point_*_temp; do
        [ -f "$tp" ] || continue
        cur="$(cat "$tp" 2>/dev/null)"
        if [ -n "$cur" ] && [ "$cur" -gt 0 ] 2>/dev/null; then
            new=$((cur + thermal_headroom))
            write_sys "$tp" "$new"
        fi
    done

    # Set polling interval
    write_sys "$tz/polling_interval" "$(conf_get thermal_polling 2000)"
done

# ---- Thermal Engine Policy ----
# MAX PERFORMANCE — disable thermal engine completely
thermal_mode="$(conf_get thermal_mode performance)"

case "$thermal_mode" in
    performance)
        # Disable all thermal zones for maximum performance
        log "apply_thermal: Performance mode — disabling all thermal zones"
        for tz in /sys/class/thermal/thermal_zone*; do
            [ -d "$tz" ] || continue
            write_sys "$tz/mode" "disabled" 2>/dev/null
        done
        ;;
    balanced)
        # Keep default thermal behavior
        log "apply_thermal: Balanced mode — keeping defaults"
        ;;
    cool)
        # More aggressive cooling
        for tz in /sys/class/thermal/thermal_zone*; do
            [ -d "$tz" ] || continue
            write_sys "$tz/mode" "enabled" 2>/dev/null
        done
        ;;
esac

# ---- Power Supply ----
write_sys "/sys/class/power_supply/battery/charging_control" "$(conf_get charging_control 1)" 2>/dev/null

# ---- Thermal Mitigation ----
# CPU throttle temperatures
CPU_THROTTLE="$(conf_get cpu_throttle_temp 98000)"
GPU_THROTTLE="$(conf_get gpu_throttle_temp 98000)"

# Find and configure CPU thermal
for tz in /sys/class/thermal/thermal_zone*; do
    [ -d "$tz" ] || continue
    type="$(cat "$tz/type" 2>/dev/null)"
    case "$type" in
        *cpu*|*CPU*)
            write_sys "$tz/trip_point_0_temp" "$CPU_THROTTLE" 2>/dev/null
            ;;
        *gpu*|*GPU*)
            write_sys "$tz/trip_point_0_temp" "$GPU_THROTTLE" 2>/dev/null
            ;;
    esac
done

log "apply_thermal: Thermal management complete"
