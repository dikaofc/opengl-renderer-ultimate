#!/system/bin/sh
# ============================================================
# OpenGL Renderer Ultimate — Uninstall Cleanup
# ============================================================

# Remove persistent props
resetprop persist.debug.hwui.renderer "" 2>/dev/null
resetprop persist.debug.renderengine.backend "" 2>/dev/null
resetprop persist.window_animation_scale "" 2>/dev/null
resetprop persist.transition_animation_scale "" 2>/dev/null
resetprop persist.animator_duration_scale "" 2>/dev/null

# Reset runtime props to defaults
setprop debug.hwui.renderer skiagl
setprop debug.renderengine.backend skiagl
setprop debug.hwui.skia_tracing_enabled false
setprop debug.hwui.skia_atrace_enabled false

# Reset animations to 1x
setprop window_animation_scale 1.0
setprop transition_animation_scale 1.0
setprop animator_duration_scale 1.0

# Remove data directory
rm -rf /data/local/opengl_renderer 2>/dev/null

# Remove persistent prop file
rm -f /data/local.prop 2>/dev/null

echo "[OpenGL Renderer Ultimate] Module uninstalled, settings reverted"
