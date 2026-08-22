#!/system/bin/sh
# ============================================================
# GPU Optimization Script
# ============================================================

MODDIR="${0%/*}/.."
. "$MODDIR/scripts/functions.sh" 2>/dev/null

detect_gpu_vendor
log "apply_gpu: Starting GPU optimization ($GPU_VENDOR / $GPU_RENDERER)"

case "$GPU_VENDOR" in
    qualcomm)
        log "apply_gpu: Qualcomm Adreno detected"
        KGSL="/sys/class/kgsl/kgsl-3d0"

        if [ -d "$KGSL" ]; then
            # Governor
            gov="$(conf_get gpu_governor performance)"
            write_sys "$KGSL/devfreq/governor" "$gov"

            # Max GPU clock
            max_clk="$(conf_get gpu_freq_max "")"
            if [ -n "$max_clk" ] && [ -w "$KGSL/max_gpuclk" ]; then
                write_sys "$KGSL/max_gpuclk" "$max_clk"
            fi

            # Devfreq max/min
            write_sys "$KGSL/devfreq/max_freq" "$(conf_get gpu_devfreq_max "$(read_sys "$KGSL/devfreq/max_freq")")"
            write_sys "$KGSL/devfreq/min_freq" "$(conf_get gpu_devfreq_min "$(read_sys "$KGSL/devfreq/min_freq")")"

            # Bus scaling
            if [ -d "$KGSL/bus_scalse" ]; then
                write_sys "$KGSL/bus_scalse/gr.cl_disable" "1"
            fi

            # Force clock on
            write_sys "$KGSL/force_clk_on" "$(conf_get adreno_force_clk 1)"
            write_sys "$KGSL/idle_timer" "$(conf_get adreno_idle_timer 50)"
            write_sys "$KGSL/force_bus_on" "$(conf_get adreno_force_bus 1)"
            write_sys "$KGSL/force_rail_on" "$(conf_get adreno_force_rail 1)"

            # GPU preemption
            write_sys "$KGSL/preemption_timeout" "$(conf_get adreno_preemption 50)"

            # Adreno-specific properties
            sp "ro.vendor.gpu.adreno.idle_timeout" "50"
            sp "ro.vendor.gpu.boost" "true"
            sp "ro.vendor.gpu.early_load" "true"
            sp "debug.qcgl" "true"
            sp "debug.hwui.adreno_shader_cache" "true"

            # sysfs freq table
            if [ -f "$KGSL/gpu_available_frequencies" ]; then
                avail="$(cat "$KGSL/gpu_available_frequencies" 2>/dev/null)"
                log "apply_gpu: Adreno available freqs: $avail"
            fi
        fi
        ;;

    arm)
        log "apply_gpu: ARM Mali detected"

        # Find Mali device path
        MALI_PATH=""
        for p in /sys/devices/platform/mali* /sys/devices/platform/*/mali* /sys/devices/platform/*.gpu; do
            [ -d "$p" ] && MALI_PATH="$p" && break
        done

        # Also try /sys/class/misc/mali0 or /sys/devices/*/mali
        if [ -z "$MALI_PATH" ]; then
            MALI_PATH="$(find /sys -maxdepth 4 -name "mali*" -type d 2>/dev/null | head -1)"
        fi

        if [ -n "$MALI_PATH" ]; then
            # Governor
            gov="$(conf_get gpu_governor performance)"
            if [ -w "$MALI_PATH/devfreq/governor" ]; then
                write_sys "$MALI_PATH/devfreq/governor" "$gov"
            fi

            # Max frequency
            max="$(conf_get gpu_freq_max "")"
            if [ -n "$max" ] && [ -w "$MALI_PATH/devfreq/max_freq" ]; then
                write_sys "$MALI_PATH/devfreq/max_freq" "$max"
            fi

            # Utilisation polling
            if [ -w "$MALI_PATH/utilisation" ]; then
                write_sys "$MALI_PATH/utilisation_period" "$(conf_get mali_util_period 16)"
            fi
        fi

        # Mali-specific properties
        sp "debug.mali.afbc" "true"
        sp "debug.mali.trace" "0"
        sp "debug.hwui.mali_shader_cache" "true"
        ;;

    samsung)
        log "apply_gpu: Samsung Xclipse detected"
        sp "ro.vendor.gpu.xclipse.boost" "true"

        # Find Xclipse/RDNA path
        XD="$(find /sys -maxdepth 4 -name "xclipse*" -type d 2>/dev/null | head -1)"
        if [ -n "$XD" ] && [ -w "$XD/devfreq/governor" ]; then
            write_sys "$XD/devfreq/governor" "$(conf_get gpu_governor performance)"
        fi
        ;;

    *)
        log "apply_gpu: No vendor-specific GPU tweaks (detected: $GPU_RENDERER)"
        ;;
esac

# ---- Universal GPU Properties ----
sp "debug.egl.force_msaa" "false"
sp "debug.egl.swapinterval" "0"
sp "debug.egl.context_priority" "high"
sp "ro.hwui.use_ubwc" "true"
sp "ro.hwui.use_afbc" "true"
sp "debug.gralloc.enable_fb_ubwc" "true"
sp "debug.hwc.can_use_gpu_comp" "true"

# ---- HWC composition ----
sp "debug.hwc.can_use_gpu_comp" "true"
sp "debug.sf.enable_gl_backpressure" "true"

log "apply_gpu: GPU optimization complete"
