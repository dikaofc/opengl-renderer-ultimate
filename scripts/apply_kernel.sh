#!/system/bin/sh
# ============================================================
# Kernel Optimization Script
# ============================================================

MODDIR="${0%/*}/.."
. "$MODDIR/scripts/functions.sh" 2>/dev/null

log "apply_kernel: Starting kernel optimization"

# ---- Kernel Scheduler ----
write_sys "/proc/sys/kernel/sched_child_runs_first" "$(conf_get sched_child_runs_first 1)"
write_sys "/proc/sys/kernel/sched_tunable_scaling" "$(conf_get sched_tunable_scaling 0)"
write_sys "/proc/sys/kernel/sched_latency_ns" "$(conf_get sched_latency_ns 1000000)"
write_sys "/proc/sys/kernel/sched_min_granularity_ns" "$(conf_get sched_min_granularity_ns 500000)"
write_sys "/proc/sys/kernel/sched_wakeup_granularity_ns" "$(conf_get sched_wakeup_granularity_ns 500000)"
write_sys "/proc/sys/kernel/sched_migration_cost_ns" "$(conf_get sched_migration_cost_ns 100000)"
write_sys "/proc/sys/kernel/sched_nr_migrate" "$(conf_get sched_nr_migrate 4)"
write_sys "/proc/sys/kernel/sched_autogroup_enabled" "$(conf_get sched_autogroup 0)"
write_sys "/proc/sys/kernel/sched_cfs_bandwidth_slice_us" "$(conf_get sched_cfs_bandwidth 5000)"
write_sys "/proc/sys/kernel/sched_energy_aware" "$(conf_get sched_energy_aware 1)"

# ---- Kernel Preemption ----
write_sys "/proc/sys/kernel/preempt" "$(conf_get kernel_preempt 1)"
write_sys "/proc/sys/kernel/preemptive" "$(conf_get kernel_preemptive 1)"

# ---- HZ / Timer ----
write_sys "/proc/sys/kernel/hz_tick" "$(conf_get hz_tick 1000)"

# ---- FSYNC ----
write_sys "/proc/sys/fs/fsync" "$(conf_get fsync 1)"

# ---- BPF JIT ----
write_sys "/proc/sys/net/core/bpf_jit_enable" "$(conf_get bpf_jit 1)"

# ---- SysRq (debug shortcut) ----
write_sys "/proc/sys/kernel/sysrq" "$(conf_get sysrq 0)"

# ---- Process Hardening ----
write_sys "/proc/sys/kernel/yama/ptrace_scope" "$(conf_get ptrace_scope 1)"

# ---- Namespaces ----
write_sys "/proc/sys/kernel/unprivileged_userns_clone" "$(conf_get unprivileged_userns 1)"

# ---- Random ----
write_sys "/proc/sys/kernel/random/read_wakeup_threshold" "$(conf_get random_read_wakeup 64)"
write_sys "/proc/sys/kernel/random/write_wakeup_threshold" "$(conf_get random_write_wakeup 128)"
write_sys "/proc/sys/kernel/random/entropy_avail" "$(conf_get random_entropy 256)"

# ---- Reboot ----
write_sys "/proc/sys/kernel/panic_on_oops" "$(conf_get panic_on_oops 1)"
write_sys "/proc/sys/kernel/panic" "$(conf_get kernel_panic 10)"

# ---- Printk ----
write_sys "/proc/sys/kernel/printk" "$(conf_get printk '1 4 1 7')"

# ---- Domain ----
write_sys "/proc/sys/kernel/domainname" "$(conf_get domainname localdomain)"

# ---- Asymmetric Per-CPU ----
write_sys "/proc/sys/kernel/sched_asym_prefer_energy" "$(conf_get sched_asym_energy 1)"

log "apply_kernel: Kernel optimization complete"
