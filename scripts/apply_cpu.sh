#!/system/bin/sh
# ============================================================
# CPU Optimization Script
# ============================================================

MODDIR="${0%/*}/.."
. "$MODDIR/scripts/functions.sh" 2>/dev/null

detect_cpu
log "apply_cpu: Starting CPU optimization ($CPU_CORES cores)"

# ---- Cache config values outside loops (avoid repeated forks) ----
_gov="$(conf_get cpu_governor performance)"
_max="$(conf_get cpu_max_freq "")"
_min="$(conf_get cpu_min_freq "")"

# ---- CPU Governor ----
for i in $(seq 0 $((CPU_CORES - 1))); do
    cpu="/sys/devices/system/cpu/cpu$i/cpufreq"
    [ -d "$cpu" ] || continue
    write_sys "$cpu/scaling_governor" "$_gov"
    [ -n "$_max" ] && write_sys "$cpu/scaling_max_freq" "$_max"
    [ -n "$_min" ] && write_sys "$cpu/scaling_min_freq" "$_min"
done

# ---- Scheduler Tuning ----
write_sys "/proc/sys/kernel/sched_child_runs_first" "$(conf_get sched_child_runs_first 1)"
write_sys "/proc/sys/kernel/sched_tunable_scaling" "$(conf_get sched_tunable_scaling 0)"
write_sys "/proc/sys/kernel/sched_latency_ns" "$(conf_get sched_latency_ns 1000000)"
write_sys "/proc/sys/kernel/sched_min_granularity_ns" "$(conf_get sched_min_granularity_ns 500000)"
write_sys "/proc/sys/kernel/sched_wakeup_granularity_ns" "$(conf_get sched_wakeup_granularity_ns 500000)"
write_sys "/proc/sys/kernel/sched_migration_cost_ns" "$(conf_get sched_migration_cost_ns 100000)"
write_sys "/proc/sys/kernel/sched_nr_migrate" "$(conf_get sched_nr_migrate 4)"

# ---- CFS Scheduler ----
write_sys "/proc/sys/kernel/sched_cfs_bandwidth_slice_us" "$(conf_get sched_cfs_bandwidth_slice 5000)"

# ---- Energy Aware Scheduling ----
for i in $(seq 0 $((CPU_CORES - 1))); do
    eas="/sys/devices/system/cpu/cpu$i/cpufreq/schedutil"
    if [ -d "$eas" ]; then
        write_sys "$eas/up_rate_limit_us" "$(conf_get schedutil_up_rate 500)"
        write_sys "$eas/down_rate_limit_us" "$(conf_get schedutil_down_rate 20000)"
    fi
done

# ---- CPU Boost ----
write_sys "/sys/module/cpu_boost/parameters/input_boost_freq" "$(conf_get input_boost_freq 0)"
write_sys "/sys/module/cpu_boost/parameters/input_boost_ms" "$(conf_get input_boost_ms 50)"
write_sys "/sys/module/cpu_boost/parameters/sched_boost_on_input" "$(conf_get sched_boost_on_input 1)"

# ---- CPU Idle ----
for i in $(seq 0 $((CPU_CORES - 1))); do
    idle="/sys/devices/system/cpu/cpu$i/cpuidle"
    if [ -d "$idle" ]; then
        for state in "$idle"/state*; do
            [ -f "$state/disable" ] && write_sys "$state/disable" "$(conf_get cpu_idle_disable 0)"
        done
    fi
done

# ---- Core Hotplug ----
write_sys "/sys/devices/system/cpu/core_ctl/enable" "$(conf_get core_ctl_enable 0)"

# NOTE: Thermal trip point modification is handled by apply_thermal.sh exclusively
# to avoid race conditions between parallel scripts.

log "apply_cpu: CPU optimization complete"
