#!/system/bin/sh
# ============================================================
# Network Optimization Script
# ============================================================

MODDIR="${0%/*}/.."
. "$MODDIR/scripts/functions.sh" 2>/dev/null

log "apply_network: Starting network optimization"

# ---- TCP Congestion Control ----
tcp_algo="$(conf_get tcp_congestion bbr)"

# Load available algorithms
for mod in tcp_bbr tcp_cubic tcp_vegas tcp_reno tcp_nwmod; do
    modprobe "$mod" 2>/dev/null
done

write_sys "/proc/sys/net/ipv4/tcp_congestion_control" "$tcp_algo"
write_sys "/proc/sys/net/core/default_qdisc" "$(conf_get default_qdisc fq)"

# ---- TCP Buffer Sizes ----
write_sys "/proc/sys/net/core/rmem_max" "$(conf_get tcp_rmem_max 16777216)"
write_sys "/proc/sys/net/core/wmem_max" "$(conf_get tcp_wmem_max 16777216)"
write_sys "/proc/sys/net/core/rmem_default" "$(conf_get tcp_rmem_default 1048576)"
write_sys "/proc/sys/net/core/wmem_default" "$(conf_get tcp_wmem_default 1048576)"
write_sys "/proc/sys/net/ipv4/tcp_rmem" "$(conf_get tcp_rmem '4096 1048576 16777216')"
write_sys "/proc/sys/net/ipv4/tcp_wmem" "$(conf_get tcp_wmem '4096 1048576 16777216')"

# ---- TCP Performance ----
write_sys "/proc/sys/net/ipv4/tcp_fastopen" "$(conf_get tcp_fastopen 3)"
write_sys "/proc/sys/net/ipv4/tcp_slow_start_after_idle" "$(conf_get tcp_slow_start 0)"
write_sys "/proc/sys/net/ipv4/tcp_mtu_probing" "$(conf_get tcp_mtu_probe 1)"
write_sys "/proc/sys/net/ipv4/tcp_sack" "$(conf_get tcp_sack 1)"
write_sys "/proc/sys/net/ipv4/tcp_timestamps" "$(conf_get tcp_timestamps 1)"
write_sys "/proc/sys/net/ipv4/tcp_window_scaling" "$(conf_get tcp_window_scaling 1)"
write_sys "/proc/sys/net/ipv4/tcp_no_metrics_save" "$(conf_get tcp_no_metrics 1)"
write_sys "/proc/sys/net/ipv4/tcp_frto" "$(conf_get tcp_frto 2)"
write_sys "/proc/sys/net/ipv4/tcp_ecn" "$(conf_get tcp_ecn 0)"
write_sys "/proc/sys/net/ipv4/tcp_adv_win_scale" "$(conf_get tcp_adv_win 1)"

# ---- TCP Keepalive ----
write_sys "/proc/sys/net/ipv4/tcp_keepalive_time" "$(conf_get tcp_keepalive 600)"
write_sys "/proc/sys/net/ipv4/tcp_keepalive_intvl" "$(conf_get tcp_keepalive_intvl 30)"
write_sys "/proc/sys/net/ipv4/tcp_keepalive_probes" "$(conf_get tcp_keepalive_probes 5)"

# ---- TCP Backlog ----
write_sys "/proc/sys/net/core/netdev_max_backlog" "$(conf_get netdev_backlog 4096)"
write_sys "/proc/sys/net/core/somaxconn" "$(conf_get somaxconn 4096)"

# ---- SYN Cookies ----
write_sys "/proc/sys/net/ipv4/tcp_syncookies" "$(conf_get tcp_syncookies 1)"

# ---- IP fragmentation ----
write_sys "/proc/sys/net/ipv4/ipfrag_high_thresh" "$(conf_get ipfrag_high 4194304)"
write_sys "/proc/sys/net/ipv4/ipfrag_low_thresh" "$(conf_get ipfrag_low 3145728)"

# ---- Conntrack ----
write_sys "/net/netfilter/nf_conntrack_max" "$(conf_get conntrack_max 65536)"

# ---- Network Power Saving ----
write_sys "/sys/class/net/wlan*/power_save" "$(conf_get wifi_power_save 0)" 2>/dev/null

# ---- Wireless optimization ----
for iface in /sys/class/net/wlan* /sys/class/net/eth*; do
    [ -d "$iface" ] || continue
    write_sys "$iface/queues/rx-0/rps_sock_flow_entries" "$(conf_get rps_flow 32768)"
    write_sys "$iface/queues/tx-0/xps_cpus" "$(conf_get xps_cpus 255)"
done

log "apply_network: Network optimization complete"
