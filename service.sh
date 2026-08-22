#!/system/bin/sh
# ============================================================
# OpenGL Renderer Ultimate — service.sh
# Runs after boot complete, after all services started
# ============================================================

MODDIR="${0%/*}"
CONF="/data/local/opengl_renderer/config.conf"
LOG="/data/local/opengl_renderer/logs/service_$(date +%Y%m%d_%H%M%S).log"

# Load shared functions
. "$MODDIR/scripts/functions.sh" 2>/dev/null

log "service.sh: Module service started"

# ---- Wait for system to fully boot ----
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
done
sleep 3  # Extra wait for services to stabilize

log "service.sh: System boot completed"

# ---- Apply all subsystem optimizations ----
log "service.sh: Applying CPU optimizations..."
"$MODDIR/scripts/apply_cpu.sh" &
log "service.sh: Applying GPU optimizations..."
"$MODDIR/scripts/apply_gpu.sh" &
log "service.sh: Applying RAM optimizations..."
"$MODDIR/scripts/apply_ram.sh" &
log "service.sh: Applying kernel optimizations..."
"$MODDIR/scripts/apply_kernel.sh" &
log "service.sh: Applying network optimizations..."
"$MODDIR/scripts/apply_network.sh" &
log "service.sh: Applying thermal settings..."
"$MODDIR/scripts/apply_thermal.sh" &
log "service.sh: Applying overclock settings..."
"$MODDIR/scripts/apply_overclock.sh" &

# Wait for all background jobs
wait

# ---- Apply saved config if exists ----
if [ -f "$CONF" ]; then
    log "service.sh: Applying saved config..."
    apply_config "$CONF"
fi

# ---- GPU Vendor specific ----
detect_gpu_vendor
log "service.sh: GPU vendor detected: $GPU_VENDOR ($GPU_RENDERER)"

case "$GPU_VENDOR" in
    qualcomm)
        "$MODDIR/scripts/apply_gpu.sh" adreno
        ;;
    arm)
        "$MODDIR/scripts/apply_gpu.sh" mali
        ;;
    samsung)
        "$MODDIR/scripts/apply_gpu.sh" xclipse
        ;;
esac

# ---- Write persistent props ----
log "service.sh: Writing persistent props..."
write_persistent_props

# ---- Final verification ----
log "service.sh: Final verification..."
verify_props

log "service.sh: All optimizations applied successfully"
log "service.sh: WebUI available at http://localhost:port in KernelSU Manager"
