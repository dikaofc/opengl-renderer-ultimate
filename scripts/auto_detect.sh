#!/system/bin/sh
# ============================================================
# Auto Detect & Optimal Settings — OpenGL Renderer Ultimate
# ============================================================
# Usage:
#   auto_detect.sh scan       — Scan hardware and report
#   auto_detect.sh recommend  — Recommend optimal profile
#   auto_detect.sh apply      — Apply recommended settings
#   auto_detect.sh profile    — Generate optimal config.conf
# ============================================================

MODDIR="${0%/*}/.."
. "$MODDIR/scripts/functions.sh" 2>/dev/null

RESULTS_DIR="$CONF_DIR/auto_detect"
mkdir -p "$RESULTS_DIR" 2>/dev/null

# ---- Hardware Scanner ----
scan_hardware() {
    detect_cpu
    detect_gpu_vendor
    detect_ram

    # SOC Details
    local soc="$(getprop ro.board.platform 2>/dev/null)"
    local soc_model="$(getprop ro.soc.model 2>/dev/null)"
    local soc_manufacturer="$(getprop ro.soc.manufacturer 2>/dev/null)"

    # CPU Architecture
    local cpu_arch="$(uname -m 2>/dev/null)"
    local cpu_implementer=""
    local cpu_part=""
    if [ -f /proc/cpuinfo ]; then
        cpu_implementer=$(grep "CPU implementer" /proc/cpuinfo | head -1 | awk -F: '{print $2}' | tr -d ' ')
        cpu_part=$(grep "CPU part" /proc/cpuinfo | head -1 | awk -F: '{print $2}' | tr -d ' ')
    fi

    # CPU Cluster Detection (big.LITTLE)
    local cpu_clusters=1
    local has_big=0
    local has_little=0
    local max_possible=0
    local min_possible=999999999

    for i in $(seq 0 $((CPU_CORES - 1))); do
        local freq="/sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_max_freq"
        if [ -f "$freq" ]; then
            local f=$(cat "$freq" 2>/dev/null)
            if [ -n "$f" ] && [ "$f" -gt 0 ] 2>/dev/null; then
                [ "$f" -gt "$max_possible" ] && max_possible=$f
                [ "$f" -lt "$min_possible" ] && min_possible=$f
            fi
        fi
    done

    # Detect big.LITTLE
    if [ "$max_possible" -gt 0 ] && [ "$min_possible" -gt 0 ] 2>/dev/null; then
        local ratio=$((max_possible / min_possible))
        if [ "$ratio" -gt 2 ]; then
            has_big=1
            has_little=1
        fi
    fi

    # GPU Details
    local gpu_model=""
    local gpu_max_clk=0
    local gpu_avail_freqs=""

    case "$GPU_VENDOR" in
        qualcomm)
            local kgsl="/sys/class/kgsl/kgsl-3d0"
            if [ -d "$kgsl" ]; then
                gpu_model=$(cat "$kgsl/gpu_model" 2>/dev/null)
                gpu_max_clk=$(cat "$kgsl/max_gpuclk" 2>/dev/null || echo 0)
                gpu_avail_freqs=$(cat "$kgsl/gpu_available_frequencies" 2>/dev/null)
            fi
            ;;
        arm)
            local mali=$(find /sys -maxdepth 4 -name "mali*" -type d 2>/dev/null | head -1)
            if [ -n "$mali" ] && [ -d "$mali/devfreq" ]; then
                gpu_max_clk=$(cat "$mali/devfreq/max_freq" 2>/dev/null || echo 0)
                gpu_avail_freqs=$(cat "$mali/devfreq/available_frequencies" 2>/dev/null)
            fi
            ;;
    esac

    # RAM Speed
    local ram_speed=""
    if [ -f /sys/devices/system/memory/*/ dram_freq ]; then
        ram_speed=$(cat /sys/devices/system/memory/*/dram_freq 2>/dev/null | head -1)
    fi

    # Storage Type
    local storage_type="unknown"
    if [ -b /dev/block/mmcblk0 ]; then
        storage_type="emmc"
        local card_size=$(cat /sys/block/mmcblk0/size 2>/dev/null)
        if [ -n "$card_size" ]; then
            storage_type="emmc_$(echo "scale=0; $card_size / 2097152" | bc 2>/dev/null)GB"
        fi
    elif [ -b /dev/block/sda ]; then
        storage_type="ufs"
    fi

    # Thermal Sensors
    local thermal_zones=0
    local max_temp=0
    for tz in /sys/class/thermal/thermal_zone*; do
        [ -d "$tz" ] || continue
        thermal_zones=$((thermal_zones + 1))
        local t=$(cat "$tz/temp" 2>/dev/null)
        if [ -n "$t" ] && [ "$t" -gt "$max_temp" ] 2>/dev/null; then
            max_temp=$t
        fi
    done

    # Kernel Version
    local kernel=$(uname -r 2>/dev/null)

    # Android SDK
    local sdk=$(getprop ro.build.version.sdk 2>/dev/null)

    # Build Type
    local build_type=$(getprop ro.build.type 2>/dev/null)
    local is_custom_rom=0
    local rom_name=$(getprop ro.build.display.id 2>/dev/null)
    case "$rom_name" in
        *LineageOS*|*Lineage*|*AOSP*|*crDroid*|*PixelExperience*|*ArrowOS*|*Evolution*|*Havoc*|*Resurrection*|*Superior*|*DotOS*|*Paranoid*|*DerpFest*|*AICP*|*Project*|*AOKP*)
            is_custom_rom=1
            ;;
    esac
    # Check for common custom ROM props
    if [ "$(getprop ro.modversion 2>/dev/null)" != "" ]; then is_custom_rom=1; fi
    if [ "$(getprop ro.custom.build.version 2>/dev/null)" != "" ]; then is_custom_rom=1; fi

    cat << EOF
{
  "device": {
    "model": "$(getprop ro.product.model 2>/dev/null)",
    "brand": "$(getprop ro.product.brand 2>/dev/null)",
    "device": "$(getprop ro.product.device 2>/dev/null)",
    "android": "$(getprop ro.build.version.release 2>/dev/null)",
    "sdk": $sdk,
    "build_type": "$build_type",
    "is_custom_rom": $is_custom_rom,
    "rom_info": "$rom_name"
  },
  "soc": {
    "platform": "$soc",
    "model": "$soc_model",
    "manufacturer": "$soc_manufacturer",
    "arch": "$cpu_arch",
    "implementer": "$cpu_implementer",
    "part": "$cpu_part"
  },
  "cpu": {
    "cores": $CPU_CORES,
    "max_freq": $max_possible,
    "min_freq": $min_possible,
    "has_big_lITTLE": $has_big,
    "governor": "$CPU_GOVERNOR"
  },
  "gpu": {
    "vendor": "$GPU_VENDOR",
    "renderer": "$GPU_RENDERER",
    "model": "$gpu_model",
    "max_clock": $gpu_max_clk,
    "available_freqs": "$gpu_avail_freqs"
  },
  "ram": {
    "total_kb": $RAM_TOTAL,
    "total_mb": $((RAM_TOTAL / 1024)),
    "available_kb": $RAM_AVAIL,
    "speed": "$ram_speed"
  },
  "storage": {
    "type": "$storage_type"
  },
  "thermal": {
    "zones": $thermal_zones,
    "max_temp_millideg": $max_temp,
    "current_temp_c": $((max_temp / 1000))
  },
  "kernel": "$kernel"
}
EOF
}

# ---- Recommend Settings ----
recommend_settings() {
    detect_cpu
    detect_gpu_vendor
    detect_ram

    local profile="balanced"
    local reason=""
    local ram_mb=$((RAM_TOTAL / 1024))
    local max_freq=0

    for i in $(seq 0 $((CPU_CORES - 1))); do
        local f=$(cat /sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_max_freq 2>/dev/null)
        if [ -n "$f" ] && [ "$f" -gt "$max_freq" ] 2>/dev/null; then
            max_freq=$f
        fi
    done
    local max_mhz=$((max_freq / 1000))

    # ---- Determine Profile ----

    # Flagship: 8 cores, 2.5GHz+, 6GB+ RAM, Adreno 6xx/7xx or Mali G7xx
    if [ "$CPU_CORES" -ge 8 ] && [ "$max_mhz" -ge 2500 ] && [ "$ram_mb" -ge 6000 ]; then
        profile="flagship"
        reason="8+ cores, ${max_mhz}MHz, ${ram_mb}MB RAM — flagship hardware detected"

    # High-end: 8 cores, 2GHz+, 4GB+ RAM
    elif [ "$CPU_CORES" -ge 8 ] && [ "$max_mhz" -ge 2000 ] && [ "$ram_mb" -ge 4000 ]; then
        profile="high_end"
        reason="8 cores, ${max_mhz}MHz, ${ram_mb}MB RAM — high-end device"

    # Mid-range: 6-8 cores, 1.5GHz+, 3GB+ RAM
    elif [ "$CPU_CORES" -ge 6 ] && [ "$max_mhz" -ge 1500 ] && [ "$ram_mb" -ge 3000 ]; then
        profile="mid_range"
        reason="6+ cores, ${max_mhz}MHz, ${ram_mb}MB RAM — mid-range device"

    # Low-end: 4 cores, <1.5GHz or <3GB RAM
    elif [ "$CPU_CORES" -le 4 ] || [ "$max_mhz" -lt 1500 ] || [ "$ram_mb" -lt 3000 ]; then
        profile="low_end"
        reason="4 cores / ${max_mhz}MHz / ${ram_mb}MB RAM — low-end device, conservative settings"

    else
        profile="balanced"
        reason="Default balanced profile"
    fi

    # Override for custom ROM — can push harder
    local sdk=$(getprop ro.build.version.sdk 2>/dev/null)
    if [ "$sdk" -ge 30 ] 2>/dev/null; then
        reason="$reason (Android 11+ detected — full API support)"
    fi

    cat << EOF
{
  "profile": "$profile",
  "reason": "$reason",
  "hardware_summary": {
    "cpu_cores": $CPU_CORES,
    "cpu_max_mhz": $max_mhz,
    "gpu": "$GPU_RENDERER",
    "ram_mb": $ram_mb
  }
}
EOF
}

# ---- Generate Optimal Config ----
generate_optimal_config() {
    detect_cpu
    detect_gpu_vendor
    detect_ram

    local ram_mb=$((RAM_TOTAL / 1024))
    local max_freq=0
    for i in $(seq 0 $((CPU_CORES - 1))); do
        local f=$(cat /sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_max_freq 2>/dev/null)
        if [ -n "$f" ] && [ "$f" -gt "$max_freq" ] 2>/dev/null; then
            max_freq=$f
        fi
    done
    local max_mhz=$((max_freq / 1000))

    # Determine profile tier
    local tier="balanced"
    if [ "$CPU_CORES" -ge 8 ] && [ "$max_mhz" -ge 2500 ] && [ "$ram_mb" -ge 6000 ]; then
        tier="flagship"
    elif [ "$CPU_CORES" -ge 8 ] && [ "$max_mhz" -ge 2000 ] && [ "$ram_mb" -ge 4000 ]; then
        tier="high_end"
    elif [ "$CPU_CORES" -ge 6 ] && [ "$max_mhz" -ge 1500 ] && [ "$ram_mb" -ge 3000 ]; then
        tier="mid_range"
    elif [ "$CPU_CORES" -le 4 ] || [ "$max_mhz" -lt 1500 ] || [ "$ram_mb" -lt 3000 ]; then
        tier="low_end"
    fi

    # Generate config based on tier
    case "$tier" in
        flagship)
            cat << 'CONF'
# ============================================================
# OPTIMAL CONFIG — Flagship Device
# Auto-generated by OpenGL Renderer Ultimate
# ============================================================

# ---- CPU ----
cpu_governor=performance
overclock_enabled=1
oc_governor=performance
governor_lock=1
input_boost_freq=0
input_boost_ms=50
sched_boost_on_input=1
sched_latency_ns=500000
sched_min_granularity_ns=250000
sched_wakeup_granularity_ns=250000
sched_migration_cost_ns=50000
sched_nr_migrate=8

# ---- GPU ----
gpu_governor=performance
gpu_overclock_enabled=1
adreno_force_clk=1
adreno_idle_timer=0
adreno_force_bus=1
adreno_force_rail=1

# ---- RAM (generous) ----
swappiness=120
dirty_ratio=50
dirty_background_ratio=15
vfs_cache_pressure=40
min_free_kbytes=16384
extra_free_kbytes=12288
zram_algorithm=lz4
ksm_run=1
ksm_pages_to_scan=200

# ---- I/O ----
io_scheduler=bfq
readahead=4096
nr_requests=256
io_overclock=1

# ---- Kernel ----
sched_autogroup=0
fsync=1
bpf_jit=1

# ---- Network ----
tcp_congestion=bbr
default_qdisc=fq
tcp_fastopen=3

# ---- Thermal (max headroom) ----
thermal_mode=performance
thermal_headroom=10000
cpu_throttle_temp=98000
gpu_throttle_temp=98000

# ---- Bus ----
bus_overclock=1
CONF
            ;;
        high_end)
            cat << 'CONF'
# ============================================================
# OPTIMAL CONFIG — High-End Device
# ============================================================

# ---- CPU ----
cpu_governor=performance
overclock_enabled=1
oc_governor=performance
governor_lock=1
input_boost_freq=0
input_boost_ms=50
sched_boost_on_input=1
sched_latency_ns=750000
sched_min_granularity_ns=400000
sched_wakeup_granularity_ns=400000
sched_migration_cost_ns=75000
sched_nr_migrate=6

# ---- GPU ----
gpu_governor=performance
gpu_overclock_enabled=1
adreno_force_clk=1
adreno_idle_timer=25
adreno_force_bus=1
adreno_force_rail=1

# ---- RAM ----
swappiness=110
dirty_ratio=45
dirty_background_ratio=12
vfs_cache_pressure=45
min_free_kbytes=14336
extra_free_kbytes=10240
zram_algorithm=lz4
ksm_run=1
ksm_pages_to_scan=150

# ---- I/O ----
io_scheduler=bfq
readahead=2048
nr_requests=128
io_overclock=1

# ---- Kernel ----
sched_autogroup=0
fsync=1
bpf_jit=1

# ---- Network ----
tcp_congestion=bbr
default_qdisc=fq
tcp_fastopen=3

# ---- Thermal ----
thermal_mode=performance
thermal_headroom=7500
cpu_throttle_temp=96000
gpu_throttle_temp=96000

# ---- Bus ----
bus_overclock=1
CONF
            ;;
        mid_range)
            cat << 'CONF'
# ============================================================
# OPTIMAL CONFIG — Mid-Range Device
# ============================================================

# ---- CPU ----
cpu_governor=schedutil
overclock_enabled=1
oc_governor=performance
governor_lock=0
input_boost_freq=0
input_boost_ms=50
sched_boost_on_input=1
sched_latency_ns=1000000
sched_min_granularity_ns=500000
sched_wakeup_granularity_ns=500000
sched_migration_cost_ns=100000
sched_nr_migrate=4

# ---- GPU ----
gpu_governor=msm-adreno-tz
gpu_overclock_enabled=0
adreno_force_clk=0
adreno_idle_timer=50
adreno_force_bus=0
adreno_force_rail=0

# ---- RAM ----
swappiness=100
dirty_ratio=40
dirty_background_ratio=10
vfs_cache_pressure=50
min_free_kbytes=12288
extra_free_kbytes=8192
zram_algorithm=lz4
ksm_run=1
ksm_pages_to_scan=100

# ---- I/O ----
io_scheduler=bfq
readahead=2048
nr_requests=64
io_overclock=0

# ---- Kernel ----
sched_autogroup=0
fsync=1
bpf_jit=1

# ---- Network ----
tcp_congestion=bbr
default_qdisc=fq
tcp_fastopen=3

# ---- Thermal ----
thermal_mode=balanced
thermal_headroom=5000
cpu_throttle_temp=90000
gpu_throttle_temp=90000

# ---- Bus ----
bus_overclock=0
CONF
            ;;
        low_end)
            cat << 'CONF'
# ============================================================
# OPTIMAL CONFIG — Low-End Device (Conservative)
# ============================================================

# ---- CPU ----
cpu_governor=schedutil
overclock_enabled=0
oc_governor=schedutil
governor_lock=0
input_boost_freq=0
input_boost_ms=0
sched_boost_on_input=0
sched_latency_ns=1500000
sched_min_granularity_ns=750000
sched_wakeup_granularity_ns=750000
sched_migration_cost_ns=200000
sched_nr_migrate=2

# ---- GPU ----
gpu_governor=simple_ondemand
gpu_overclock_enabled=0
adreno_force_clk=0
adreno_idle_timer=100
adreno_force_bus=0
adreno_force_rail=0

# ---- RAM (conservative) ----
swappiness=80
dirty_ratio=30
dirty_background_ratio=5
vfs_cache_pressure=100
min_free_kbytes=8192
extra_free_kbytes=4096
zram_algorithm=lz4
ksm_run=1
ksm_pages_to_scan=50

# ---- I/O ----
io_scheduler=bfq
readahead=1024
nr_requests=32
io_overclock=0

# ---- Kernel ----
sched_autogroup=1
fsync=1
bpf_jit=0

# ---- Network ----
tcp_congestion=cubic
default_qdisc=fq
tcp_fastopen=1

# ---- Thermal ----
thermal_mode=balanced
thermal_headroom=3000
cpu_throttle_temp=85000
gpu_throttle_temp=85000

# ---- Bus ----
bus_overclock=0
CONF
            ;;
    esac
}

# ---- Main Dispatch ----
case "$1" in
    scan)
        scan_hardware
        ;;
    recommend)
        recommend_settings
        ;;
    apply)
        echo "Generating optimal config..."
        generate_optimal_config > "$CONF"
        echo "Applying config..."
        apply_config "$CONF"
        echo "OK: Optimal settings applied"
        ;;
    profile)
        generate_optimal_config
        ;;
    *)
        echo "OpenGL Renderer Ultimate — Auto Detect"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  scan       Scan hardware and report all specs"
        echo "  recommend  Recommend optimal profile for this device"
        echo "  apply      Generate and apply optimal settings"
        echo "  profile    Print optimal config.conf to stdout"
        ;;
esac
