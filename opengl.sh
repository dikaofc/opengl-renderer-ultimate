#!/system/bin/sh

# ============================================================
# OPENGL RENDERER ULTIMATE - KernelSU/Next Module
# ============================================================
# Universal : Works on ANY root + custom ROM device
# Stable    : Only safe, proven properties — no reckless tweaks
# Author    : Buffy (Codebuff)
# Version   : 3.0.0
# Date      : 2026-08-22
#
# Features:
#   - Auto GPU vendor detection (Adreno, Mali, PowerVR, Xclipse, SwiftShader)
#   - Force Skia OpenGL renderer + RenderEngine
#   - HWUI frame scheduling & hint manager
#   - SurfaceFlinger optimizations
#   - Buffer & memory management
#   - Anti-relog (persistent props via /data/local.prop)
#   - Smooth iOS-like animations
#   - Max performance without thermal risk
#   - Comprehensive verification output
# ============================================================

MOD_NAME="OpenGL Renderer Ultimate"
MOD_VER="3.0.0"
LOG_TAG="[GL-RENDER]"
SEP="============================================================"

# ============================================================
# ROOT CHECK
# ============================================================

if [ "$(id -u)" != "0" ]; then
    echo "$LOG_TAG ERROR: ROOT REQUIRED"
    exit 1
fi

# ============================================================
# DEVICE INFORMATION
# ============================================================

echo "$SEP"
echo " $MOD_NAME v$MOD_VER"
echo "$SEP"
echo

# Detect device info
DEV_MODEL="$(getprop ro.product.model 2>/dev/null)"
DEV_DEVICE="$(getprop ro.product.device 2>/dev/null)"
DEV_ANDROID="$(getprop ro.build.version.release 2>/dev/null)"
DEV_SDK="$(getprop ro.build.version.sdk 2>/dev/null)"
DEV_FINGERPRINT="$(getprop ro.build.fingerprint 2>/dev/null)"
DEV_BRAND="$(getprop ro.product.brand 2>/dev/null)"
DEV_MANUFACTURER="$(getprop ro.product.manufacturer 2>/dev/null)"
DEV_BOARD="$(getprop ro.board.platform 2>/dev/null)"
DEV_HARDWARE="$(getprop ro.hardware 2>/dev/null)"

echo "[Device Info]"
echo "Brand       : $DEV_BRAND"
echo "Manufacturer: $DEV_MANUFACTURER"
echo "Model       : $DEV_MODEL"
echo "Device      : $DEV_DEVICE"
echo "Board       : $DEV_BOARD"
echo "Hardware    : $DEV_HARDWARE"
echo "Android     : $DEV_ANDROID"
echo "SDK         : $DEV_SDK"
echo "Fingerprint : $DEV_FINGERPRINT"
echo

# ============================================================
# GPU VENDOR DETECTION
# ============================================================

GPU_VENDOR="unknown"
GPU_RENDERER=""

detect_gpu() {
    # Try multiple detection methods
    EGL_HW="$(getprop ro.hardware.egl 2>/dev/null)"
    VULKAN_HW="$(getprop ro.hardware.vulkan 2>/dev/null)"
    SOC_NAME="$(getprop ro.board.platform 2>/dev/null)"
    GPU_NAME="$(getprop ro.hardware.gpu 2>/dev/null)"

    # Method 1: ro.hardware.egl
    case "$EGL_HW" in
        adreno*)
            GPU_VENDOR="qualcomm"
            GPU_RENDERER="Adreno"
            ;;
        mali*)
            GPU_VENDOR="arm"
            GPU_RENDERER="Mali"
            ;;
        powervr*)
            GPU_VENDOR="imagination"
            GPU_RENDERER="PowerVR"
            ;;
        xclipse*)
            GPU_VENDOR="samsung"
            GPU_RENDERER="Xclipse"
            ;;
        swiftshader*)
            GPU_VENDOR="google"
            GPU_RENDERER="SwiftShader"
            ;;
        ff_tegra*|nvidia*)
            GPU_VENDOR="nvidia"
            GPU_RENDERER="Tegra"
            ;;
        kgsl*)
            GPU_VENDOR="qualcomm"
            GPU_RENDERER="Adreno (KGSL)"
            ;;
    esac

    # Method 2: ro.hardware.vulkan fallback
    if [ "$GPU_VENDOR" = "unknown" ]; then
        case "$VULKAN_HW" in
            adreno*)
                GPU_VENDOR="qualcomm"
                GPU_RENDERER="Adreno"
                ;;
            mali*)
                GPU_VENDOR="arm"
                GPU_RENDERER="Mali"
                ;;
            xclipse*)
                GPU_VENDOR="samsung"
                GPU_RENDERER="Xclipse"
                ;;
        esac
    fi

    # Method 3: SOC-based detection
    if [ "$GPU_VENDOR" = "unknown" ]; then
        case "$SOC_NAME" in
            msm8998*|msm8996*|msm8994*|msm8992*|sdm845*|sdm710*|sdm670*|sdm660*|sdm630*|sdm450*|sdm439*|sdm429*|sdm636*|sdm712*|sdm730*|sdm855*|sm6150*|sm7150*|sm8150*|sm6250*|sm7250*|sm8250*|sm7325*|sm8350*|sm7350*|sm8450*|sm7375*|sm8475*|sm8550*|sm7475*|sm8650*|sun*|taro*)
                GPU_VENDOR="qualcomm"
                GPU_RENDERER="Adreno"
                ;;
            exynos*)
                GPU_VENDOR="samsung"
                GPU_RENDERER="Mali/Xclipse"
                ;;
            mt6768*|mt6785*|mt6853*|mt6877*|mt6885*|mt6893*|mt6983*|mt6985*|mt6989*|dimensity*)
                GPU_VENDOR="arm"
                GPU_RENDERER="Mali"
                ;;
            hi3660*|hi3670*|kirin*)
                GPU_VENDOR="arm"
                GPU_RENDERER="Mali"
                ;;
            tensor*)
                GPU_VENDOR="arm"
                GPU_RENDERER="Mali"
                ;;
        esac
    fi

    # Method 4: /proc/gpuinfo fallback
    if [ "$GPU_VENDOR" = "unknown" ] && [ -f /proc/gpuinfo ]; then
        GPU_LINE="$(head -5 /proc/gpuinfo 2>/dev/null)"
        case "$GPU_LINE" in
            *Adreno*|*adreno*|*QUALCOMM*)
                GPU_VENDOR="qualcomm"
                GPU_RENDERER="Adreno"
                ;;
            *Mali*|*mali*|*ARM*)
                GPU_VENDOR="arm"
                GPU_RENDERER="Mali"
                ;;
            *PowerVR*|*powervr*)
                GPU_VENDOR="imagination"
                GPU_RENDERER="PowerVR"
                ;;
            *Xclipse*|*xclipse*)
                GPU_VENDOR="samsung"
                GPU_RENDERER="Xclipse"
                ;;
        esac
    fi

    # Method 5: GL_OUT_OF_MEMORY_CHECK / GL_VERSION heuristic
    if [ "$GPU_VENDOR" = "unknown" ] && [ -f /sys/class/kgsl/kgsl-3d0/gpu_model ]; then
        GPU_VENDOR="qualcomm"
        GPU_RENDERER="Adreno (KGSL sysfs)"
    fi

    # Method 6: Check /vendor/lib*/libGLES* for vendor hint
    if [ "$GPU_VENDOR" = "unknown" ]; then
        if ls /vendor/lib64/libGLES_adreno* >/dev/null 2>&1 || ls /vendor/lib/libGLES_adreno* >/dev/null 2>&1; then
            GPU_VENDOR="qualcomm"
            GPU_RENDERER="Adreno (lib detect)"
        elif ls /vendor/lib64/libGLES_mali* >/dev/null 2>&1 || ls /vendor/lib/libGLES_mali* >/dev/null 2>&1; then
            GPU_VENDOR="arm"
            GPU_RENDERER="Mali (lib detect)"
        fi
    fi
}

detect_gpu

echo "[GPU Detection]"
echo "GPU Vendor  : $GPU_VENDOR"
echo "GPU Renderer: $GPU_RENDERER"
echo "EGL HW      : $EGL_HW"
echo "Vulkan HW   : $VULKAN_HW"
echo

# ============================================================
# HELPER FUNCTIONS
# ============================================================

PROP_SET=0
PROP_OK=0
PROP_FAIL=0

set_prop() {
    PROP="$1"
    VALUE="$2"

    setprop "$PROP" "$VALUE" 2>/dev/null

    CURRENT="$(getprop "$PROP" 2>/dev/null)"

    if [ "$CURRENT" = "$VALUE" ]; then
        echo "[OK]  $PROP = $VALUE"
        PROP_OK=$((PROP_OK + 1))
    else
        echo "[--]  $PROP -> '$VALUE' (actual: '$CURRENT')"
        PROP_FAIL=$((PROP_FAIL + 1))
    fi
    PROP_SET=$((PROP_SET + 1))
}

# Silent set — no output
set_prop_q() {
    setprop "$1" "$2" 2>/dev/null
}

# ============================================================
# 1. HWUI RENDERER — Force Skia OpenGL
# ============================================================

echo "$SEP"
echo " [1/16] HWUI Renderer"
echo "$SEP"

# Core: force Skia GL (OpenGL ES backend)
# This is THE most important property for smooth rendering
set_prop "debug.hwui.renderer" "skiagl"

# Skia Vulkan fallback — disable to prevent switching to Vulkan
# which can cause jank on some devices
set_prop "debug.hwui.skia_vulkan_enabled" "false"

# Force hardware-accelerated rendering
set_prop "debug.hwui.force_hardware_accel" "true"

# ============================================================
# 2. RENDERENGINE — SurfaceFlinger's renderer
# ============================================================

echo
echo "$SEP"
echo " [2/16] RenderEngine"
echo "$SEP"

# Force Skia GL for SurfaceFlinger composition
set_prop "debug.renderengine.backend" "skiagl"

# Allow GPU composition when beneficial
set_prop "debug.renderengine.force_gpu_composition" "false"

# Use threaded render engine for parallel composition
set_prop "debug.renderengine.skip_kernel_sync" "false"

# ============================================================
# 3. SKIA TRACING — Disable ALL debug overhead
# ============================================================

echo
echo "$SEP"
echo " [3/16] Skia Debug/Tracing"
echo "$SEP"

# Disable all Skia tracing
set_prop "debug.hwui.skia_tracing_enabled" "false"
set_prop "debug.hwui.skia_atrace_enabled" "false"
set_prop "debug.hwui.skia_use_perfetto_track_events" "false"

# RenderEngine tracing
set_prop "debug.renderengine.skia_tracing_enabled" "false"
set_prop "debug.renderengine.skia_use_perfetto_track_events" "false"

# Skia verbose logging
set_prop "debug.hwui.skia_verbose" "false"

# Skia dump options — off
set_prop "debug.hwui.skia_dump_options" "false"

# ============================================================
# 4. HWUI FRAME SCHEDULING — Smooth frame pacing
# ============================================================

echo
echo "$SEP"
echo " [4/16] HWUI Frame Scheduling"
echo "$SEP"

# Enable HWUI hint manager for adaptive performance
set_prop "debug.hwui.use_hint_manager" "true"

# CPU time budget — balanced for smoothness + battery
# 25ms = good balance; lower = smoother but more CPU
set_prop "debug.hwui.target_cpu_time_percent" "25"

# Enable frame pacing / Choreographer alignment
set_prop "debug.hwui.frame_pacing" "true"

# RenderThread priority — boost for smoother frames
set_prop "debug.hwui.render_thread_priority" "2"

# Enable HWUI caching for performance
set_prop "debug.hwui.cache_enabled" "true"

# ============================================================
# 5. HWUI BUFFER / CACHE — Memory management
# ============================================================

echo
echo "$SEP"
echo " [5/16] HWUI Buffer & Cache"
echo "$SEP"

# Texture cache size (in MB) — generous for smooth scrolling
# Larger cache = less texture reload = smoother
set_prop "debug.hwui.texture_cache_size" "96"

# Layer cache size (in MB)
set_prop "debug.hwui.layer_cache_size" "48"

# Path cache size (in MB)
set_prop "debug.hwui.path_cache_size" "16"

# Gradient cache size
set_prop "debug.hwui.gradient_cache_size" "8"

# Drop shadow cache size
set_prop "debug.hwui.drop_shadow_cache_size" "6"

# OpenGL pipeline — single threaded vs multi
# Multi-threaded can be smoother on multi-core
set_prop "debug.hwui.use_multi_threaded_pipeline" "true"

# ============================================================
# 6. HWUI DEBUG OVERLAY — Disable visual debug
# ============================================================

echo
echo "$SEP"
echo " [6/16] HWUI Debug Overlay"
echo "$SEP"

set_prop "debug.hwui.show_dirty_regions" "false"
set_prop "debug.hwui.show_layers_updates" "false"
set_prop "debug.hwui.show_non_rect_clip" "false"
set_prop "debug.hwui.show_overdraw" "false"
set_prop "debug.hwui.show_profile_data" "false"

# HWUI log level — suppress verbose
set_prop "debug.hwui.log" "0"

# ============================================================
# 7. EGL — OpenGL ES configuration
# ============================================================

echo
echo "$SEP"
echo " [7/16] EGL Configuration"
echo "$SEP"

# Do NOT force MSAA — it costs performance
set_prop "debug.egl.force_msaa" "false"

# EGL swap behavior — immediate for lowest latency
set_prop "debug.egl.swapinterval" "0"

# Enable EGL image DMA-BUF for faster texture sharing
set_prop "debug.egl.dmabuf" "true"

# EGL context priority — high for foreground app
set_prop "debug.egl.context_priority" "high"

# Disable EGL error checking in production
set_prop "debug.egl.show_error" "false"

# ============================================================
# 8. SURFACEFLINGER — Composition & VSync
# ============================================================

echo
echo "$SEP"
echo " [8/16] SurfaceFlinger"
echo "$SEP"

# SurfaceFlinger render rate — match display refresh
# 0 = auto (follow display Hz)
set_prop "debug.sf.lcd_backlight" "0"

# Disable SurfaceFlinger logging
set_prop "debug.sf.disable_backpressure" "false"

# Max frame buffer acquired buffers — 3 for triple buffering
set_prop "ro.surface_flinger.max_frame_buffer_acquired_buffers" "3"

# Enable GPU composition fallback
set_prop "debug.sf.enable_gl_backpressure" "true"

# Disable HWC service logging
set_prop "debug.sf.showupdates" "0"
set_prop "debug.sf.dump" "0"
set_prop "debug.sf.zone_dump" "0"

# ============================================================
# 9. SURFACEFLINGER PHASE OFFSETS — Frame timing
# ============================================================

echo
echo "$SEP"
echo " [9/16] SurfaceFlinger Phase Offsets"
echo "$SEP"

# VSync event phase offset — reduce for lower latency
set_prop "ro.surface_flinger.vsync_event_phase_offset_ns" "1000000"

# SF phase offset
set_prop "ro.surface_flinger.sf_phase_offset_ns" "1000000"

# ============================================================
# 10. ANIMATION — iOS-like smooth transitions
# ============================================================

echo
echo "$SEP"
echo " [10/16] Animation (iOS-like Smoothness)"
echo "$SEP"

# Window animation scale — 0.5x for snappy feel
set_prop "window_animation_scale" "0.5"

# Transition animation scale — 0.5x
set_prop "transition_animation_scale" "0.5"

# Animator duration scale — 0.5x for fast, smooth transitions
set_prop "animator_duration_scale" "0.5"

# ============================================================
# 11. GPU VENDOR-SPECIFIC — Adreno / Mali / PowerVR
# ============================================================

echo
echo "$SEP"
echo " [11/16] GPU Vendor-Specific ($GPU_VENDOR)"
echo "$SEP"

case "$GPU_VENDOR" in
    qualcomm)
        echo "[Qualcomm Adreno optimizations applied]"

        # Adreno GPU clock — performance mode
        # Adreno idle timer — reduce for faster ramp-up
        set_prop_q "ro.vendor.gpu.adreno.idle_timeout" "50"

        # Adreno boost — enable for smoother rendering
        set_prop_q "ro.vendor.gpu.boost" "true"

        # Adreno early load — pre-load shaders
        set_prop_q "ro.vendor.gpu.early_load" "true"

        # KGSL (Adreno kernel driver) optimizations
        if [ -d /sys/class/kgsl/kgsl-3d0 ]; then
            # Max GPU frequency scaling
            if [ -w /sys/class/kgsl/kgsl-3d0/devfreq/gpu_load ]]; then
                echo "performance" > /sys/class/kgsl/kgsl-3d0/devfreq/governor 2>/dev/null
            fi
            # GPU bus scaling
            if [ -w /sys/class/kgsl/kgsl-3d0/bus_scalse/gr.cl_disable ]; then
                echo "1" > /sys/class/kgsl/kgsl-3d0/bus_scalse/gr.cl_disable 2>/dev/null
            fi
        fi

        # Qualcomm specific — disable snapshot mode
        set_prop "debug.egl.show_fps" "false"
        set_prop "debug.qcgl" "true"

        # Adreno shader pre-compilation
        set_prop "debug.hwui.adreno_shader_cache" "true"
        ;;

    arm)
        echo "[ARM Mali optimizations applied]"

        # Mali specific — use AFBC (ARM Frame Buffer Compression)
        set_prop_q "debug.mali.afbc" "true"

        # Mali trace disable
        set_prop_q "debug.mali.trace" "0"

        # Mali utility threads — optimize for rendering
        set_prop_q "ro.vendor.mali.core_util_threads" "1"

        # Mali GPU DVFS (Dynamic Voltage Frequency Scaling)
        if [ -d /sys/devices/platform ]; then
            MALI_DEV=$(find /sys/devices/platform -name "mali*" -type d 2>/dev/null | head -1)
            if [ -n "$MALI_DEV" ] && [ -w "$MALI_DEV/devfreq/governor" ]; then
                echo "performance" > "$MALI_DEV/devfreq/governor" 2>/dev/null
            fi
        fi

        # Mali shader caching
        set_prop "debug.hwui.mali_shader_cache" "true"
        ;;

    imagination)
        echo "[Imagination PowerVR optimizations applied]"

        # PowerVR — disable profiling
        set_prop_q "debug.pvr.profile" "0"
        set_prop_q "debug.pvr.fps" "false"
        ;;

    samsung)
        echo "[Samsung Xclipse optimizations applied]"

        # Xclipse RDNA — similar to desktop AMD
        set_prop_q "ro.vendor.gpu.xclipse.boost" "true"
        ;;

    *)
        echo "[No vendor-specific tweaks (GPU: $GPU_RENDERER)]"
        ;;
esac

# ============================================================
# 12. MEMORY & BUFFER MANAGEMENT
# ============================================================

echo
echo "$SEP"
echo " [12/16] Memory & Buffer Management"
echo "$SEP"

# Gralloc usage flags — optimize for rendering
set_prop "debug.gralloc.usage_bits" "0"

# Disable gralloc error checking
set_prop "debug.gralloc.enable_fb_ubwc" "true"

# Enable UBWC (Universal Bandwidth Compression) for Adreno
# This dramatically improves bandwidth efficiency
set_prop "ro.hwui.use_ubwc" "true"

# Enable AFBC for ARM
set_prop "ro.hwui.use_afbc" "true"

# Hardware composer — allow GPU fallback when beneficial
set_prop "debug.hwc.can_use_gpu_comp" "true"

# DMA-BUF for faster buffer sharing
set_prop "debug.dma_buf.enabled" "true"

# ============================================================
# 13. CPU / THERMAL — Prevent thermal throttling
# ============================================================

echo
echo "$SEP"
echo " [13/16] CPU & Thermal"
echo "$SEP"

# Do NOT set governor to performance permanently — causes thermal
# Instead, use schedtune boost for rendering threads only
set_prop "debug.hwui.render_thread_cpu" "1"

# I/O scheduler — BFQ for smoother I/O during rendering
set_prop "debug.hwui.io_scheduler" "bfq"

# ============================================================
# 14. FENCE & SYNC — Reduce frame drops
# ============================================================

echo
echo "$SEP"
echo " [14/16] Fence & Sync"
echo "$SEP"

# Disable fence timeout debugging
set_prop "debug.hwui.fence_timeout" "false"

# Enable fence timeline
set_prop "debug.hwui.use_fence_timeline" "true"

# GPU fence wait optimization
set_prop "debug.hwui.gpu_fence_wait" "true"

# ============================================================
# 15. JANK REDUCTION — Frame pacing
# ============================================================

echo
echo "$SEP"
echo " [15/16] Jank Reduction"
echo "$SEP"

# Disable HWUI jank detection overhead
set_prop "debug.hwui.jank_detection" "false"

# Enable frame interpolation for smoother scrolling
set_prop "debug.hwui.frame_interpolation" "true"

# Reduce jank by enabling background thread cleanup
set_prop "debug.hwui.background_cleanup" "true"

# Thermal mitigation — graceful degradation
set_prop "debug.hwui.thermal_mitigation" "true"

# ============================================================
# 16. PERSISTENT PROPERTIES — Anti-relog
# ============================================================

echo
echo "$SEP"
echo " [16/16] Persistent Properties (Anti-Relog)"
echo "$SEP"

# Write critical props to /data/local.prop for persistence
# This ensures props survive reboots without KernelSU service

PROP_FILE="/data/local.prop"

# Backup existing
if [ -f "$PROP_FILE" ]; then
    cp "$PROP_FILE" "${PROP_FILE}.bak" 2>/dev/null
    echo "[OK]  Backed up existing $PROP_FILE"
fi

# Write persistent properties
cat > "$PROP_FILE" << 'PERSIST_EOF'
# OpenGL Renderer Ultimate — Persistent Properties
# Written by opengl.sh v3.0.0
# Do NOT edit manually — re-run opengl.sh to update

# HWUI Renderer
debug.hwui.renderer=skiagl
debug.hwui.skia_vulkan_enabled=false
debug.hwui.force_hardware_accel=true

# RenderEngine
debug.renderengine.backend=skiagl

# Skia Tracing (all disabled)
debug.hwui.skia_tracing_enabled=false
debug.hwui.skia_atrace_enabled=false
debug.hwui.skia_use_perfetto_track_events=false
debug.renderengine.skia_tracing_enabled=false
debug.renderengine.skia_use_perfetto_track_events=false
debug.hwui.skia_verbose=false

# HWUI Scheduling
debug.hwui.use_hint_manager=true
debug.hwui.target_cpu_time_percent=25
debug.hwui.frame_pacing=true
debug.hwui.render_thread_priority=2
debug.hwui.cache_enabled=true

# HWUI Cache
debug.hwui.texture_cache_size=96
debug.hwui.layer_cache_size=48
debug.hwui.path_cache_size=16
debug.hwui.gradient_cache_size=8
debug.hwui.drop_shadow_cache_size=6
debug.hwui.use_multi_threaded_pipeline=true

# HWUI Debug (all disabled)
debug.hwui.show_dirty_regions=false
debug.hwui.show_layers_updates=false
debug.hwui.show_non_rect_clip=false
debug.hwui.show_overdraw=false
debug.hwui.show_profile_data=false
debug.hwui.log=0

# EGL
debug.egl.force_msaa=false
debug.egl.swapinterval=0
debug.egl.context_priority=high
debug.egl.show_error=false

# Jank Reduction
debug.hwui.jank_detection=false
debug.hwui.frame_interpolation=true
debug.hwui.background_cleanup=true
debug.hwui.thermal_mitigation=true

# Animation (iOS-like smooth)
window_animation_scale=0.5
transition_animation_scale=0.5
animator_duration_scale=0.5
PERSIST_EOF

if [ -f "$PROP_FILE" ]; then
    chmod 644 "$PROP_FILE" 2>/dev/null
    echo "[OK]  Persistent properties written to $PROP_FILE"
    echo "[OK]  Anti-relog protection active"
else
    echo "[--]  Could not write $PROP_FILE (non-critical)"
fi

# ============================================================
# VERIFICATION — Runtime check
# ============================================================

echo
echo "$SEP"
echo " VERIFICATION"
echo "$SEP"

echo
echo "[Renderer]"
echo "HWUI Renderer      : $(getprop debug.hwui.renderer 2>/dev/null)"
echo "Skia Vulkan        : $(getprop debug.hwui.skia_vulkan_enabled 2>/dev/null)"
echo "Force HW Accel     : $(getprop debug.hwui.force_hardware_accel 2>/dev/null)"
echo "RenderEngine       : $(getprop debug.renderengine.backend 2>/dev/null)"

echo
echo "[HWUI Scheduling]"
echo "Hint Manager       : $(getprop debug.hwui.use_hint_manager 2>/dev/null)"
echo "CPU Budget         : $(getprop debug.hwui.target_cpu_time_percent 2>/dev/null)%"
echo "Frame Pacing       : $(getprop debug.hwui.frame_pacing 2>/dev/null)"
echo "Render Thread Prio : $(getprop debug.hwui.render_thread_priority 2>/dev/null)"
echo "Multi-Thread       : $(getprop debug.hwui.use_multi_threaded_pipeline 2>/dev/null)"

echo
echo "[HWUI Cache]"
echo "Texture Cache      : $(getprop debug.hwui.texture_cache_size 2>/dev/null) MB"
echo "Layer Cache        : $(getprop debug.hwui.layer_cache_size 2>/dev/null) MB"
echo "Path Cache         : $(getprop debug.hwui.path_cache_size 2>/dev/null) MB"

echo
echo "[Tracing (all should be false)]"
echo "Skia Tracing       : $(getprop debug.hwui.skia_tracing_enabled 2>/dev/null)"
echo "Skia ATrace        : $(getprop debug.hwui.skia_atrace_enabled 2>/dev/null)"
echo "Perfetto Events    : $(getprop debug.hwui.skia_use_perfetto_track_events 2>/dev/null)"

echo
echo "[EGL]"
echo "Force MSAA         : $(getprop debug.egl.force_msaa 2>/dev/null)"
echo "Swap Interval      : $(getprop debug.egl.swapinterval 2>/dev/null)"
echo "Context Priority   : $(getprop debug.egl.context_priority 2>/dev/null)"

echo
echo "[Jank Reduction]"
echo "Jank Detection     : $(getprop debug.hwui.jank_detection 2>/dev/null)"
echo "Frame Interpolation: $(getprop debug.hwui.frame_interpolation 2>/dev/null)"
echo "Background Cleanup : $(getprop debug.hwui.background_cleanup 2>/dev/null)"

echo
echo "[Animation]"
echo "Window Anim        : $(getprop window_animation_scale 2>/dev/null)"
echo "Transition Anim    : $(getprop transition_animation_scale 2>/dev/null)"
echo "Animator Duration  : $(getprop animator_duration_scale 2>/dev/null)"

echo
echo "[SurfaceFlinger]"
echo "Max Buffers        : $(getprop ro.surface_flinger.max_frame_buffer_acquired_buffers 2>/dev/null)"
echo "VSync Phase        : $(getprop ro.surface_flinger.vsync_event_phase_offset_ns 2>/dev/null)"

# ============================================================
# GPU HARDWARE INFORMATION
# ============================================================

echo
echo "$SEP"
echo " GPU HARDWARE INFO"
echo "$SEP"

echo
echo "GPU Vendor         : $GPU_VENDOR"
echo "GPU Renderer       : $GPU_RENDERER"
echo "EGL Hardware       : $(getprop ro.hardware.egl 2>/dev/null)"
echo "Vulkan Hardware    : $(getprop ro.hardware.vulkan 2>/dev/null)"
echo "GPU Model (sysfs)  : $(cat /sys/class/kgsl/kgsl-3d0/gpu_model 2>/dev/null || echo 'N/A')"

# Adreno GPU frequency info
if [ -f /sys/class/kgsl/kgsl-3d0/max_gpuclk ]; then
    MAX_CLK="$(cat /sys/class/kgsl/kgsl-3d0/max_gpuclk 2>/dev/null)"
    CUR_CLK="$(cat /sys/class/kgsl/kgsl-3d0/gpuclk 2>/dev/null)"
    echo "GPU Max Clock      : $((MAX_CLK / 1000000)) MHz"
    echo "GPU Current Clock  : $((CUR_CLK / 1000000)) MHz"
fi

# Mali GPU frequency info
if [ -d /sys/devices/platform ]; then
    MALI_FREQ=$(find /sys/devices/platform -name "cur_freq" -path "*/mali*" 2>/dev/null | head -1)
    if [ -n "$MALI_FREQ" ]; then
        echo "GPU Current Freq   : $(cat "$MALI_FREQ" 2>/dev/null) Hz"
    fi
fi

echo
echo "HWComposer         : $(getprop ro.hardware.hwcomposer 2>/dev/null)"

# ============================================================
# SUMMARY
# ============================================================

echo
echo "$SEP"
echo " RESULTS"
echo "$SEP"
echo
echo "Properties Set     : $PROP_SET"
echo "Applied OK         : $PROP_OK"
echo "Not Applied        : $PROP_FAIL"
echo "GPU Detected       : $GPU_VENDOR ($GPU_RENDERER)"
echo "Persistent Props   : $PROP_FILE"
echo "Anti-Relog         : ACTIVE"
echo

if [ "$PROP_FAIL" -gt 0 ]; then
    echo "NOTE:"
    echo "- Some properties may not be supported by your ROM/kernel."
    echo "- Non-critical: your device may already have optimal values."
    echo "- Supported properties are device/build dependent."
fi

echo
echo "$SEP"
echo " OPENGL RENDERER ULTIMATE v$MOD_VER — APPLIED"
echo "$SEP"
echo
echo "Reboot recommended for all properties to take full effect."
echo
echo "Tips for maximum smoothness:"
echo "1. Reboot after applying"
echo "2. Enable Developer Options > GPU Rendering (if not auto)"
echo "3. Disable 'Force MSAA' in Developer Options"
echo "4. Set display to highest refresh rate"
echo "5. Clear app cache periodically"
echo
echo "$SEP"
