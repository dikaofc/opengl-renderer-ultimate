#!/system/bin/sh
# ============================================================
# RAM & Memory Optimization Script
# ============================================================

MODDIR="${0%/*}/.."
. "$MODDIR/scripts/functions.sh" 2>/dev/null

detect_ram
log "apply_ram: Starting RAM optimization (Total: ${RAM_TOTAL}kB)"

# ---- Virtual Memory Tuning ----
write_sys "/proc/sys/vm/swappiness" "$(conf_get swappiness 100)"
write_sys "/proc/sys/vm/dirty_ratio" "$(conf_get dirty_ratio 40)"
write_sys "/proc/sys/vm/dirty_background_ratio" "$(conf_get dirty_background_ratio 10)"
write_sys "/proc/sys/vm/dirty_writeback_centisecs" "$(conf_get dirty_writeback 500)"
write_sys "/proc/sys/vm/dirty_expire_centisecs" "$(conf_get dirty_expire 3000)"
write_sys "/proc/sys/vm/vfs_cache_pressure" "$(conf_get vfs_cache_pressure 50)"
write_sys "/proc/sys/vm/min_free_kbytes" "$(conf_get min_free_kbytes 12288)"
write_sys "/proc/sys/vm/extra_free_kbytes" "$(conf_get extra_free_kbytes 8192)"
write_sys "/proc/sys/vm/watermark_boost_factor" "$(conf_get watermark_boost 15000)"
write_sys "/proc/sys/vm/watermark_scale_factor" "$(conf_get watermark_scale 100)"
write_sys "/proc/sys/vm/page-cluster" "$(conf_get page_cluster 3)"
write_sys "/proc/sys/vm/overcommit_memory" "$(conf_get overcommit_memory 0)"
write_sys "/proc/sys/vm/overcommit_ratio" "$(conf_get overcommit_ratio 50)"
write_sys "/proc/sys/vm/drop_caches" "3"

# ---- ZRAM ----
# Detect and configure ZRAM
ZRAM_DEV=""
for z in /dev/block/zram*; do
    [ -b "$z" ] && ZRAM_DEV="$z" && break
done

if [ -n "$ZRAM_DEV" ]; then
    log "apply_ram: ZRAM found at $ZRAM_DEV"

    # ZRAM size — set to configurable value
    zram_size="$(conf_get zram_size "")"
    if [ -n "$zram_size" ]; then
        echo 1 > /sys/block/zram0/reset 2>/dev/null
        sleep 1
        echo "$zram_size" > /sys/block/zram0/disksize 2>/dev/null
        log "apply_ram: ZRAM disksize set to $zram_size"
    fi

    # ZRAM compression algorithm
    algo="$(conf_get zram_algorithm lz4)"
    write_sys "/sys/block/zram0/comp_algorithm" "$algo"

    # ZRAM max streams
    write_sys "/sys/block/zram0/max_comp_streams" "$(conf_get zram_max_streams "$(nproc 2>/dev/null)")"

    # Make swap on ZRAM
    if ! swapon -s 2>/dev/null | grep -q "zram"; then
        mkswap "$ZRAM_DEV" 2>/dev/null
        swapon -p 100 "$ZRAM_DEV" 2>/dev/null
        log "apply_ram: ZRAM swap activated"
    fi
else
    log "apply_ram: No ZRAM device found"
fi

# ---- Swap Priority ----
# Enable all swap devices with higher priority
for swp in /dev/block/zram* /dev/block/swap*; do
    [ -b "$swp" ] || continue
    if ! swapon -s 2>/dev/null | grep -q "$swp"; then
        mkswap "$swp" 2>/dev/null
        swapon -p 100 "$swp" 2>/dev/null
    fi
done

# ---- Readahead ----
readahead="$(conf_get readahead 2048)"
for block in /sys/block/sd*/queue/read_ahead_kb /sys/block/dm-*/queue/read_ahead_kb /sys/block/mmcblk*/queue/read_ahead_kb; do
    [ -w "$block" ] && write_sys "$block" "$readahead"
done

# ---- I/O Scheduler ----
io_sched="$(conf_get io_scheduler bfq)"
for queue in /sys/block/*/queue/scheduler; do
    [ -w "$queue" ] || continue
    cur="$(cat "$queue" 2>/dev/null)"
    if echo "$cur" | grep -q "$io_sched"; then
        write_sys "$queue" "$io_sched"
    fi
done

# ---- I/O Tuning ----
for queue in /sys/block/*/queue; do
    [ -d "$queue" ] || continue
    write_sys "$queue/nr_requests" "$(conf_get nr_requests 64)"
    write_sys "$queue/read_ahead_kb" "$readahead"
    write_sys "$queue/rq_affinity" "$(conf_get rq_affinity 2)"
    write_sys "$queue/nomerges" "$(conf_get nomerges 0)"
    write_sys "$queue/add_random" "$(conf_get add_random 0)"
done

# ---- KSM (Kernel Same-page Merging) ----
write_sys "/sys/kernel/mm/ksm/run" "$(conf_get ksm_run 1)"
write_sys "/sys/kernel/mm/ksm/pages_to_scan" "$(conf_get ksm_pages_to_scan 100)"
write_sys "/sys/kernel/mm/ksm/sleep_millisecs" "$(conf_get ksm_sleep 20)"
write_sys "/sys/kernel/mm/ksm/max_page_sharing" "$(conf_get ksm_max_sharing 256)"

# ---- Zswap ----
write_sys "/sys/module/zswap/parameters/enabled" "$(conf_get zswap_enabled Y)"
write_sys "/sys/module/zswap/parameters/max_pool_percent" "$(conf_get zswap_max_pool 25)"
write_sys "/sys/module/zswap/parameters/compressor" "$(conf_get zswap_compressor lz4)"
write_sys "/sys/module/zswap/parameters/zpool" "$(conf_get zswap_zpool z3fold)"

# ---- Compaction ----
write_sys "/proc/sys/vm/compact_memory" "1"
write_sys "/proc/sys/vm/drop_caches" "3"

# ---- THP (Transparent Huge Pages) ----
write_sys "/sys/kernel/mm/transparent_hugepage/enabled" "$(conf_get thp_enabled madvise)"
write_sys "/sys/kernel/mm/transparent_hugepage/defrag" "$(conf_get thp_defrag defer+madvise)"

# ---- Low Memory Killer ----
write_sys "/proc/sys/vm/minfree_order_boost" "$(conf_get minfree_boost 1)"

log "apply_ram: RAM optimization complete"
