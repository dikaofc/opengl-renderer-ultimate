#!/system/bin/sh
# ============================================================
# Overclock & Max Performance Script
# ============================================================

MODDIR="${0%/*}/.."
. "$MODDIR/scripts/functions.sh" 2>/dev/null

detect_cpu
detect_gpu_vendor
log "apply_overclock: Starting overclock/max performance"

# ---- CPU Overclock ----
oc_enabled="$(conf_get overclock_enabled 1)"

if [ "$oc_enabled" = "1" ]; then
    log "apply_overclock: CPU overclock ENABLED"

    # Set all cores to max frequency
    for i in $(seq 0 $((CPU_CORES - 1))); do
        cpu="/sys/devices/system/cpu/cpu$i/cpufreq"
        [ -d "$cpu" ] || continue

        # Get max available freq
        max_avail="$(cat "$cpu/cpuinfo_max_freq" 2>/dev/null)"
        if [ -n "$max_avail" ]; then
            write_sys "$cpu/scaling_max_freq" "$max_avail"
            write_sys "$cpu/scaling_min_freq" "$(conf_get cpu_oc_min "")"
            log "apply_overclock: CPU$i max_freq = $max_avail"
        fi

        # Set performance governor for max OC
        write_sys "$cpu/scaling_governor" "$(conf_get oc_governor performance)"

        # Boost all cores online
        write_sys "/sys/devices/system/cpu/cpu$i/online" "1"
    done

    # CPU Boost
    write_sys "/sys/module/cpu_boost/parameters/input_boost_freq" "$(conf_get oc_boost_freq 0)"
    write_sys "/sys/module/cpu_boost/parameters/input_boost_ms" "$(conf_get oc_boost_ms 50)"
    write_sys "/sys/module/cpu_boost/parameters/sched_boost_on_input" "1"

    # Boost duration
    write_sys "/sys/module/cpu_boost/parameters/input_boost_ms" "$(conf_get oc_boost_duration 50)"
else
    log "apply_overclock: CPU overclock DISABLED"
fi

# ---- GPU Overclock ----
gpu_oc="$(conf_get gpu_overclock_enabled 1)"

if [ "$gpu_oc" = "1" ]; then
    log "apply_overclock: GPU overclock ENABLED"

    case "$GPU_VENDOR" in
        qualcomm)
            KGSL="/sys/class/kgsl/kgsl-3d0"
            if [ -d "$KGSL" ]; then
                # Force max GPU clock
                max_clk="$(cat "$KGSL/gpu_available_frequencies" 2>/dev/null | tr ' ' '\n' | sort -n | tail -1)"
                if [ -n "$max_clk" ]; then
                    write_sys "$KGSL/max_gpuclk" "$max_clk"
                    write_sys "$KGSL/devfreq/max_freq" "$max_clk"
                    log "apply_overclock: Adreno max GPU clk = $max_clk"
                fi

                # Force performance governor
                write_sys "$KGSL/devfreq/governor" "performance"

                # Force all resources on
                write_sys "$KGSL/force_clk_on" "1"
                write_sys "$KGSL/force_bus_on" "1"
                write_sys "$KGSL/force_rail_on" "1"
                write_sys "$KGSL/idle_timer" "0"

                # Min bus scaling
                write_sys "$KGSL/bus_scale/settleclk" "0x1F" 2>/dev/null
            fi
            ;;
        arm)
            MALI_PATH="$(find /sys -maxdepth 4 -name "mali*" -type d 2>/dev/null | head -1)"
            if [ -n "$MALI_PATH" ]; then
                # Force max GPU frequency
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
bus_oc="$(conf_get bus_overclock 1)"
if [ "$bus_oc" = "1" ]; then
    # DDR frequency
    for ddr in /sys/class/devfreq/*ddr* /sys/class/devfreq/*memlat*; do
        [ -d "$ddr" ] || continue
        write_sys "$ddr/governor" "performance" 2>/dev/null
        max="$(cat "$ddr/available_frequencies" 2>/dev/null | tr ' ' '\n' | sort -n | tail -1)"
        [ -n "$max" ] && write_sys "$ddr/max_freq" "$max"
        log "apply_overclock: DDR max freq = $max"
    done

    # Bus bandwidth
    for bw in /sys/class/devfreq/*bw* /sys/class/devfreq/*bus*; do
        [ -d "$bw" ] || continue
        write_sys "$bw/governor" "performance" 2>/dev/null
    done
fi

# ---- I/O Overclock ----
io_oc="$(conf_get io_overclock 1)"
if [ "$io_oc" = "1" ]; then
    for queue in /sys/block/*/queue; do
        [ -d "$queue" ] || continue
        write_sys "$queue/scheduler" "$(conf_get io_oc_scheduler bfq)"
        write_sys "$queue/nr_requests" "256"
        write_sys "$queue/read_ahead_kb" "4096"
        write_sys "$queue/rq_affinity" "2"
        write_sys "$queue/nomerges" "0"
    done
fi

# ---- Governor Performance Lock ----
gov_lock="$(conf_get governor_lock 1)"
if [ "$gov_lock" = "1" ]; then
    # Lock all CPUs to performance governor
    for i in $(seq 0 $((CPU_CORES - 1))); do
        cpu="/sys/devices/system/cpu/cpu$i/cpufreq"
        [ -d "$cpu" ] || continue
        write_sys "$cpu/scaling_governor" "performance"
    done
    log "apply_overclock: All CPUs locked to performance governor"
fi

# ---- CPU Boost Config ----
write_sys "/sys/module/cpu_boost/parameters/input_boost_freq" "$(conf_get global_boost_freq 0)"
write_sys "/sys/module/cpu_boost/parameters/input_boost_ms" "$(conf_get global_boost_ms 50)"

log "apply_overclock: Overclock/max performance complete"
