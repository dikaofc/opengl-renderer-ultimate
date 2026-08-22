#!/system/bin/sh
# ============================================================
# Shared Functions — OpenGL Renderer Ultimate
# ============================================================

MODDIR="${0%/*}/.."
CONF_DIR="/data/local/opengl_renderer"
CONF="$CONF_DIR/config.conf"
LOG_DIR="$CONF_DIR/logs"

# ---- Logging ----
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$LOG_DIR/service_$(date +%Y%m%d).log" 2>/dev/null
}

# ---- Safe setprop with logging ----
sp() {
    local prop="$1"
    local val="$2"
    setprop "$prop" "$val" 2>/dev/null
    local actual="$(getprop "$prop" 2>/dev/null)"
    if [ "$actual" = "$val" ]; then
        log "[OK] $prop = $val"
    else
        log "[--] $prop -> '$val' (actual: '$actual')"
    fi
}

# ---- Safe write to sysfs ----
write_sys() {
    local path="$1"
    local val="$2"
    if [ -w "$path" ]; then
        echo "$val" > "$path" 2>/dev/null
        log "[OK] $path = $val"
    else
        log "[--] $path not writable"
    fi
}

# ---- Read sysfs safely ----
read_sys() {
    cat "$1" 2>/dev/null
}

# ---- GPU Detection ----
GPU_VENDOR="unknown"
GPU_RENDERER=""

detect_gpu_vendor() {
    local egl="$(getprop ro.hardware.egl 2>/dev/null)"
    local vk="$(getprop ro.hardware.vulkan 2>/dev/null)"
    local soc="$(getprop ro.board.platform 2>/dev/null)"

    case "$egl" in
        adreno*|kgsl*) GPU_VENDOR="qualcomm"; GPU_RENDERER="Adreno" ;;
        mali*)         GPU_VENDOR="arm"; GPU_RENDERER="Mali" ;;
        powervr*)      GPU_VENDOR="imagination"; GPU_RENDERER="PowerVR" ;;
        xclipse*)      GPU_VENDOR="samsung"; GPU_RENDERER="Xclipse" ;;
    esac

    if [ "$GPU_VENDOR" = "unknown" ]; then
        case "$vk" in
            adreno*) GPU_VENDOR="qualcomm"; GPU_RENDERER="Adreno" ;;
            mali*)   GPU_VENDOR="arm"; GPU_RENDERER="Mali" ;;
            xclipse*) GPU_VENDOR="samsung"; GPU_RENDERER="Xclipse" ;;
        esac
    fi

    if [ "$GPU_VENDOR" = "unknown" ]; then
        case "$soc" in
            msm*|sdm*|sm[0-9]*|sun*|taro*) GPU_VENDOR="qualcomm"; GPU_RENDERER="Adreno" ;;
            exynos*)   GPU_VENDOR="samsung"; GPU_RENDERER="Mali/Xclipse" ;;
            mt*|dimensity*) GPU_VENDOR="arm"; GPU_RENDERER="Mali" ;;
        esac
    fi

    if [ "$GPU_VENDOR" = "unknown" ]; then
        if ls /vendor/lib64/libGLES_adreno* >/dev/null 2>&1 || ls /vendor/lib/libGLES_adreno* >/dev/null 2>&1; then
            GPU_VENDOR="qualcomm"; GPU_RENDERER="Adreno"
        elif ls /vendor/lib64/libGLES_mali* >/dev/null 2>&1 || ls /vendor/lib/libGLES_mali* >/dev/null 2>&1; then
            GPU_VENDOR="arm"; GPU_RENDERER="Mali"
        fi
    fi
}

# ---- CPU Detection ----
CPU_CORES=0
CPU_MAX_FREQ=0
CPU_MIN_FREQ=0
CPU_GOVERNOR=""

detect_cpu() {
    CPU_CORES="$(ls -d /sys/devices/system/cpu/cpu[0-9]* 2>/dev/null | wc -l)"
    if [ "$CPU_CORES" -eq 0 ]; then
        CPU_CORES="$(nproc 2>/dev/null || echo 4)"
    fi

    # Try to get freq from first online core
    local cpu0="/sys/devices/system/cpu/cpu0/cpufreq"
    if [ -d "$cpu0" ]; then
        CPU_MAX_FREQ="$(read_sys "$cpu0/cpuinfo_max_freq")"
        CPU_MIN_FREQ="$(read_sys "$cpu0/cpuinfo_min_freq")"
        CPU_GOVERNOR="$(read_sys "$cpu0/scaling_governor")"
    fi

    log "detect_cpu: cores=$CPU_CORES max=$CPU_MAX_FREQ min=$CPU_MIN_FREQ gov=$CPU_GOVERNOR"
}

# ---- RAM Detection ----
RAM_TOTAL=0
RAM_AVAIL=0

detect_ram() {
    RAM_TOTAL="$(cat /proc/meminfo 2>/dev/null | grep MemTotal | awk '{print $2}')"
    RAM_AVAIL="$(cat /proc/meminfo 2>/dev/null | grep MemAvailable | awk '{print $2}')"
    log "detect_ram: total=${RAM_TOTAL}kB avail=${RAM_AVAIL}kB"
}

# ---- Apply config file ----
apply_config() {
    local conf="$1"
    if [ ! -f "$conf" ]; then return; fi

    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        case "$key" in
            \#*|"") continue ;;
        esac

        # Trim whitespace
        key="$(echo "$key" | tr -d ' ')"
        value="$(echo "$value" | tr -d ' ')"

        case "$key" in
            # System properties
            prop_*)
                local propname="${key#prop_}"
                sp "$propname" "$value"
                ;;
            # Sysfs writes
            sys_*)
                local syspath="${key#sys_}"
                write_sys "$syspath" "$value"
                ;;
            # CPU settings
            cpu_governor)
                detect_cpu
                for i in $(seq 0 $((CPU_CORES - 1))); do
                    write_sys "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor" "$value"
                done
                ;;
            cpu_max_freq)
                detect_cpu
                for i in $(seq 0 $((CPU_CORES - 1))); do
                    write_sys "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq" "$value"
                done
                ;;
            cpu_min_freq)
                detect_cpu
                for i in $(seq 0 $((CPU_CORES - 1))); do
                    write_sys "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_min_freq" "$value"
                done
                ;;
            cpu_online_*)
                local core_num="${key#cpu_online_}"
                write_sys "/sys/devices/system/cpu/cpu${core_num}/online" "$value"
                ;;
            # GPU settings
            gpu_freq_max)
                write_sys "/sys/class/kgsl/kgsl-3d0/max_gpuclk" "$value" 2>/dev/null
                write_sys "/sys/class/kgsl/kgsl-3d0/devfreq/max_freq" "$value" 2>/dev/null
                ;;
            gpu_governor)
                write_sys "/sys/class/kgsl/kgsl-3d0/devfreq/governor" "$value" 2>/dev/null
                ;;
            # RAM settings
            swappiness)
                write_sys "/proc/sys/vm/swappiness" "$value"
                ;;
            dirty_ratio)
                write_sys "/proc/sys/vm/dirty_ratio" "$value"
                ;;
            dirty_background_ratio)
                write_sys "/proc/sys/vm/dirty_background_ratio" "$value"
                ;;
            vfs_cache_pressure)
                write_sys "/proc/sys/vm/vfs_cache_pressure" "$value"
                ;;
            # Network settings
            tcp_congestion)
                write_sys "/proc/sys/net/ipv4/tcp_congestion_control" "$value"
                ;;
            # Kernel settings
            scheduler)
                write_sys "/proc/sys/kernel/sched_child_runs_first" "$value"
                ;;
        esac
    done < "$conf"
}

# ---- Write persistent props ----
write_persistent_props() {
    local pfile="$CONF_DIR/persistent.prop"
    cat > "$pfile" << 'PEOF'
# OpenGL Renderer Ultimate — Persistent Properties
persist.debug.hwui.renderer=skiagl
persist.debug.renderengine.backend=skiagl
persist.window_animation_scale=0.5
persist.transition_animation_scale=0.5
persist.animator_duration_scale=0.5
PEOF
    chmod 0644 "$pfile" 2>/dev/null
}

# ---- Verify all applied props ----
verify_props() {
    log "=== Verification ==="
    local props="
        debug.hwui.renderer
        debug.renderengine.backend
        debug.hwui.use_hint_manager
        debug.hwui.target_cpu_time_percent
        debug.hwui.frame_pacing
        debug.egl.force_msaa
        window_animation_scale
        transition_animation_scale
        animator_duration_scale
    "
    for p in $props; do
        log "$p = $(getprop "$p" 2>/dev/null)"
    done
    log "=== End Verification ==="
}

# ---- Parse config value ----
conf_get() {
    local key="$1"
    local default="$2"
    local val="$(grep "^$key=" "$CONF" 2>/dev/null | head -1 | cut -d'=' -f2)"
    if [ -z "$val" ]; then
        echo "$default"
    else
        echo "$val"
    fi
}

# ---- Set config value ----
conf_set() {
    local key="$1"
    local val="$2"
    if grep -q "^$key=" "$CONF" 2>/dev/null; then
        sed -i "s|^$key=.*|$key=$val|" "$CONF" 2>/dev/null
    else
        echo "$key=$val" >> "$CONF" 2>/dev/null
    fi
}
