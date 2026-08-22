#!/system/bin/sh
# ============================================================
# OpenGL Renderer Ultimate — post-fs-data.sh
# Runs BEFORE boot animation, early in boot
# ============================================================

MODDIR="${0%/*}"
CONF="/data/local/opengl_renderer/config.conf"

# Load shared functions
. "$MODDIR/scripts/functions.sh" 2>/dev/null

# Apply early boot optimizations
log "post-fs-data: Applying early boot optimizations..."

# ---- HWUI Renderer (critical — must be set early) ----
setprop persist.debug.hwui.renderer skiagl
setprop debug.hwui.renderer skiagl
setprop debug.hwui.skia_vulkan_enabled false
setprop debug.hwui.force_hardware_accel true

# ---- RenderEngine ----
setprop persist.debug.renderengine.backend skiagl
setprop debug.renderengine.backend skiagl

# ---- Disable all debug/tracing overhead ----
setprop debug.hwui.skia_tracing_enabled false
setprop debug.hwui.skia_atrace_enabled false
setprop debug.hwui.skia_use_perfetto_track_events false
setprop debug.renderengine.skia_tracing_enabled false
setprop debug.renderengine.skia_use_perfetto_track_events false
setprop debug.hwui.skia_verbose false

# ---- HWUI Scheduling ----
setprop debug.hwui.use_hint_manager true
setprop debug.hwui.target_cpu_time_percent 25
setprop debug.hwui.frame_pacing true
setprop debug.hwui.render_thread_priority 2
setprop debug.hwui.cache_enabled true
setprop debug.hwui.use_multi_threaded_pipeline true

# ---- HWUI Cache ----
setprop debug.hwui.texture_cache_size 96
setprop debug.hwui.layer_cache_size 48
setprop debug.hwui.path_cache_size 16
setprop debug.hwui.gradient_cache_size 8
setprop debug.hwui.drop_shadow_cache_size 6

# ---- Debug overlay (all OFF) ----
setprop debug.hwui.show_dirty_regions false
setprop debug.hwui.show_layers_updates false
setprop debug.hwui.show_non_rect_clip false
setprop debug.hwui.show_overdraw false
setprop debug.hwui.show_profile_data false
setprop debug.hwui.log 0

# ---- EGL ----
setprop debug.egl.force_msaa false
setprop debug.egl.swapinterval 0
setprop debug.egl.context_priority high
setprop debug.egl.show_error false

# ---- Animation (iOS-like smooth 0.5x) ----
setprop persist.window_animation_scale 0.5
setprop window_animation_scale 0.5
setprop persist.transition_animation_scale 0.5
setprop transition_animation_scale 0.5
setprop persist.animator_duration_scale 0.5
setprop animator_duration_scale 0.5

# ---- Jank reduction ----
setprop debug.hwui.jank_detection false
setprop debug.hwui.frame_interpolation true
setprop debug.hwui.background_cleanup true
setprop debug.hwui.thermal_mitigation true

# ---- SurfaceFlinger ----
setprop ro.surface_flinger.max_frame_buffer_acquired_buffers 3
setprop ro.surface_flinger.vsync_event_phase_offset_ns 1000000
setprop ro.surface_flinger.sf_phase_offset_ns 1000000
setprop debug.sf.enable_gl_backpressure true

# ---- Memory ----
setprop ro.hwui.use_ubwc true
setprop ro.hwui.use_afbc true
setprop debug.gralloc.enable_fb_ubwc true
setprop debug.hwc.can_use_gpu_comp true

# ---- Load saved config overrides ----
if [ -f "$CONF" ]; then
    apply_config "$CONF"
fi

log "post-fs-data: Early boot optimizations applied"
