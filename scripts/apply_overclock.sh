#!/system/bin/sh
# ============================================================
# Overclock & Max Performance Script
# ============================================================

MODDIR="${0%/*}/.."
. "$MODDIR/scripts/functions.sh" 2>/dev/null

detect_cpu
detect_gpu_vendor
log "apply_overclock: Starting overclock/max performance"

# ---- Cache config values outside loops ----
_oc_enabled="$(conf_get overclock_enabled 1)"
_oc_gov="$(conf_get oc_governor performance)"
_oc_boost_freq="$(conf_get oc_boost_freq 0)"
_oc_boost_ms="$(conf_get oc_boost_ms 50)"
_gpu_oc="$(conf_get gpu_overclock_enabled 1)"
_bus_oc="$(conf_get bus_overclock 1)"
_io_oc="$(conf_get io_overclock 1)"
_io_sched="$(conf_get io_oc_scheduler bfq)"
_gov_lock="$(conf_get governor_lock 1)"
_global_boost_freq="$(conf_get global_boost_freq 0)"
_global_boost_ms="$(conf_get global_boost_ms 50)"

# ---- CPU Overclock ----
if [ "$_oc_enabled" = "1" ]; then
    log "apply_overclock: CPU overclock ENABLED"

    for i in $(seq 0 $((CPU_CORES - 1))); do
        cpu="/sys/devices/system/cpu/cpu$i/cpufreq"
        [ -d "$cpu" ] || continue

        max_avail="$(cat "$cpu/cpuinfo_max_freq" 2>/dev/null)"
        if [ -n "$max_avail" ]; then
            write_sys "$cpu/scaling_max_freq" "$max_avail"
            write_sys "$cpu/scaling_min_freq" "$(conf_get cpu_oc_min "")"
            log "apply_overclock: CPU$i max_freq = $max_avail"
        fi

        write_sys "$cpu/scaling_governor" "$_oc_gov"
        write_sys "/sys/devices/system/cpu/cpu$i/online" "1"
    done

    # CPU Boost (single write, not duplicate)
    write_sys "/sys/module/cpu_boost/parameters/input_boost_freq" "$_oc_boost_freq"
    write_sys "/sys/module/cpu_boost/parameters/input_boost_ms" "$_oc_boost_ms"
    write_sys "/sys/module/cpu_boost/parameters/sched_boost_on_input" "1"
else
    log "apply_overclock: CPU overclock DISABLED"
fi

# ---- GPU Overclock ----
if [ "$_gpu_oc" = "1" ]; then
    log "apply_overclock: GPU overclock ENABLED"

    case "$GPU_VENDOR" in
        qualcomm)
            KGSL="/sys/class/kgsl/kgsl-3d0"
            if [ -d "$KGSL" ]; then
                max_clk="$(cat "$KGSL/gpu_available_frequencies" 2>/dev/null | tr ' ' '\n' | sort -n | tail -1)"
                if [ -n "$max_clk" ]; then
                    write_sys "$KGSL/max_gpuclk" "$max_clk"
                    write_sys "$KGSL/devfreq/max_freq" "$max_clk"
                    log "apply_overclock: Adreno max GPU clk = $max_clk"
                fi
                write_sys "$KGSL/devfreq/governor" "performance"
                write_sys "$KGSL/force_clk_on" "1"
                write_sys "$KGSL/force_bus_on" "1"
                write_sys "$KGSL/force_rail_on" "1"
                write_sys "$KGSL/idle_timer" "0"
            fi
            ;;
        arm)
            MALI_PATH="$(find /sys -maxdepth 4 -name "mali*" -type d 2>/dev/null | head -1)"
            if [ -n "$MALI_PATH" ]; then
                if [ -f "$MALI_PATH/devfreq/available_frequencies" ]; then
                    max_freq="$(cat "$MALI_PATH/devfreq/available_frequencies" 2>/dev/null | tr ' ' '\n' | sort -n | tail -1)"
                    write_sys "$MALI_PATH/devfreq/max_freq" "$max_freq"
                    write_sys "$MALI_PATH/devfreq/governor" "performance"
                    log "apply_overclock: Mali max freq = $max_freq"
                fi
            fi
            ;;
        samsung)
            XD="$(find /sys -maxdepth 4 -name "xclipse*" -type d 2>/dev/null | head -1)"
            if [ -n "$XD" ]; then
                max_freq="$(cat "$XD/devfreq/available_frequencies" 2>/dev/null | tr ' ' '\n' | sort -n | tail -1)"
                write_sys "$XD/devfreq/max_freq" "$max_freq"
                write_sys "$XD/devfreq/governor" "performance"
                log "apply_overclock: Xclipse max freq = $max_freq"
            fi
            ;;
    esac
fi

# ---- Bus Overclock ----
if [ "$_bus_oc" = "1" ]; then
    for ddr in /sys/class/devfreq/*ddr* /sys/class/devfreq/*memlat*; do
        [ -d "$ddr" ] || continue
        write_sys "$ddr/governor" "performance" 2>/dev/null
        max="$(cat "$ddr/available_frequencies" 2>/dev/null | tr ' ' '\n' | sort -n | tail -1)"
        [ -n "$max" ] && write_sys "$ddr/max_freq" "$max"
    done
    for bw in /sys/class/devfreq/*bw* /sys/class/devfreq/*bus*; do
        [ -d "$bw" ] || continue
        write_sys "$bw/governor" "performance" 2>/dev/null
    done
fi

# ---- I/O Overclock ----
if [ "$_io_oc" = "1" ]; then
    for queue in /sys/block/*/queue; do
        [ -d "$queue" ] || continue
        write_sys "$queue/scheduler" "$_io_sched"
        write_sys "$queue/nr_requests" "256"
        write_sys "$queue/read_ahead_kb" "4096"
        write_sys "$queue/rq_affinity" "2"
        write_sys "$queue/nomerges" "0"
    done
fi

# ---- Governor Performance Lock ----
if [ "$_gov_lock" = "1" ]; then
    for i in $(seq 0 $((CPU_CORES - 1))); do
        cpu="/sys/devices/system/cpu/cpu$i/cpufreq"
        [ -d "$cpu" ] || continue
        write_sys "$cpu/scaling_governor" "performance"
    done
    log "apply_overclock: All CPUs locked to performance governor"
fi

# ---- Global CPU Boost Config ----
write_sys "/sys/module/cpu_boost/parameters/input_boost_freq" "$_global_boost_freq"
write_sys "/sys/module/cpu_boost/parameters/input_boost_ms" "$_global_boost_ms"

log "apply_overclock: Overclock/max performance complete"
