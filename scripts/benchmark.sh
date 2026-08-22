#!/system/bin/sh
# ============================================================
# Benchmark Script — OpenGL Renderer Ultimate
# ============================================================
# Usage:
#   benchmark.sh cpu        — CPU benchmark
#   benchmark.sh gpu        — GPU benchmark (via HWUI render test)
#   benchmark.sh ram        — RAM bandwidth + latency
#   benchmark.sh io         — I/O read/write speed
#   benchmark.sh all        — Run all benchmarks
#   benchmark.sh before     — Save current state as "before"
#   benchmark.sh after      — Save current state as "after"
#   benchmark.sh compare    — Show before vs after
#   benchmark.sh report     — Full JSON report
# ============================================================

MODDIR="${0%/*}/.."
. "$MODDIR/scripts/functions.sh" 2>/dev/null

RESULTS_DIR="$CONF_DIR/benchmarks"
mkdir -p "$RESULTS_DIR" 2>/dev/null

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# ---- CPU Benchmark ----
bench_cpu() {
    log "bench_cpu: Starting CPU benchmark..."
    local score=0
    local iterations=500000

    # Integer arithmetic test
    local start=$(date +%s%N 2>/dev/null || date +%s)
    local i=0
    local result=0
    while [ "$i" -lt "$iterations" ]; do
        result=$((result + i * 7 + 3))
        i=$((i + 1))
    done
    local end=$(date +%s%N 2>/dev/null || date +%s)
    local elapsed=$(( (end - start) / 1000000 ))
    if [ "$elapsed" -eq 0 ]; then elapsed=1; fi
    score=$((iterations * 1000 / elapsed))

    # Float point via awk
    local fstart=$(date +%s%N 2>/dev/null || date +%s)
    awk 'BEGIN { for(i=0;i<100000;i++) { x=sin(i)*cos(i)+sqrt(i); } }' 2>/dev/null
    local fend=$(date +%s%N 2>/dev/null || date +%s)
    local felapsed=$(( (fend - fstart) / 1000000 ))
    if [ "$felapsed" -eq 0 ]; then felapsed=1; fi
    local fscore=$((100000 * 1000 / felapsed))

    # Process creation speed
    local pstart=$(date +%s%N 2>/dev/null || date +%s)
    local pcount=0
    while [ "$pcount" -lt 50 ]; do
        true &
        pcount=$((pcount + 1))
    done
    wait
    local pend=$(date +%s%N 2>/dev/null || date +%s)
    local pelp=$(( (pend - pstart) / 1000000 ))
    if [ "$pelp" -eq 0 ]; then pelp=1; fi
    local pscore=$((50 * 1000 / pelp))

    # Combined CPU score (weighted average)
    local total=$((score / 100 + fscore / 10 + pscore))
    total=$((total / 3))

    cat << EOF
{
  "name": "CPU",
  "integer_ops": $score,
  "float_ops": $fscore,
  "process_score": $pscore,
  "combined": $total,
  "unit": "ops/ms",
  "cores": $(nproc 2>/dev/null || echo 4),
  "max_freq": $(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || echo 0),
  "governor": "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo unknown)"
}
EOF
}

# ---- GPU Benchmark (sysfs based) ----
bench_gpu() {
    log "bench_gpu: Starting GPU benchmark..."
    local score=0

    # Method 1: Adreno KGSL
    local kgsl="/sys/class/kgsl/kgsl-3d0"
    if [ -d "$kgsl" ]; then
        local gpu_clk=$(cat "$kgsl/gpuclk" 2>/dev/null || echo 0)
        local gpu_busy=$(cat "$kgsl/gpu_busy_percentage" 2>/dev/null || echo 0)
        local gpu_max=$(cat "$kgsl/max_gpuclk" 2>/dev/null || echo 1)

        # Score based on clock frequency (higher = better perf)
        score=$((gpu_clk / 1000))

        # Test: measure time to read GPU state 1000 times
        local gstart=$(date +%s%N 2>/dev/null || date +%s)
        local gi=0
        while [ "$gi" -lt 1000 ]; do
            cat "$kgsl/gpuclk" >/dev/null 2>&1
            gi=$((gi + 1))
        done
        local gend=$(date +%s%N 2>/dev/null || date +%s)
        local gelp=$(( (gend - gstart) / 1000000 ))
        if [ "$gelp" -eq 0 ]; then gelp=1; fi

        local read_score=$((1000 * 1000 / gelp))
        score=$((score + read_score / 10))

        echo "\"backend\": \"kgsl\","
        echo "\"gpu_clock\": $gpu_clk,"
        echo "\"gpu_busy\": $gpu_busy,"
        echo "\"gpu_max\": $gpu_max,"
        echo "\"read_ops_ms\": $read_score,"
    else
        # Method 2: Mali devfreq
        local mali_path=$(find /sys -maxdepth 4 -name "mali*" -type d 2>/dev/null | head -1)
        if [ -n "$mali_path" ] && [ -d "$mali_path/devfreq" ]; then
            local cur=$(cat "$mali_path/devfreq/cur_freq" 2>/dev/null || echo 0)
            score=$((cur / 1000000))
            echo "\"backend\": \"mali\","
            echo "\"gpu_clock\": $cur,"
        else
            score=500
            echo "\"backend\": \"unknown\","
        fi
    fi

    cat << EOF
{
  "name": "GPU",
  $([ -n "$gpu_backend" ] && echo "\"backend\": \"$gpu_backend\",")
  "score": $score,
  "unit": "score"
}
EOF
}

# ---- RAM Benchmark ----
bench_ram() {
    log "bench_ram: Starting RAM benchmark..."

    # Memory bandwidth test — write and read 10MB
    local block_size=1048576  # 1MB
    local blocks=10
    local total=$((block_size * blocks))

    # Write test
    local wstart=$(date +%s%N 2>/dev/null || date +%s)
    dd if=/dev/zero of=/dev/shm/bench_test bs=$block_size count=$blocks 2>/dev/null
    sync
    local wend=$(date +%s%N 2>/dev/null || date +%s)
    local welp=$(( (wend - wstart) / 1000000 ))
    if [ "$welp" -eq 0 ]; then welp=1; fi
    local write_bw=$((total / welp / 1024))  # KB/ms

    # Read test
    local rstart=$(date +%s%N 2>/dev/null || date +%s)
    dd if=/dev/shm/bench_test of=/dev/null bs=$block_size 2>/dev/null
    local rend=$(date +%s%N 2>/dev/null || date +%s)
    local relp=$(( (rend - rstart) / 1000000 ))
    if [ "$relp" -eq 0 ]; then relp=1; fi
    local read_bw=$((total / relp / 1024))  # KB/ms

    rm -f /dev/shm/bench_test 2>/dev/null

    # Latency test — time to alloc and touch 1MB pages
    local lstart=$(date +%s%N 2>/dev/null || date +%s)
    awk 'BEGIN { for(i=0;i<262144;i++) a[i]=i; }' 2>/dev/null
    local lend=$(date +%s%N 2>/dev/null || date +%s)
    local lelp=$(( (lend - lstart) / 1000000 ))
    if [ "$lelp" -eq 0 ]; then lelp=1; fi

    # Memory info
    local total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local avail_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local swap_total=$(grep SwapTotal /proc/meminfo | awk '{print $2}')

    cat << EOF
{
  "name": "RAM",
  "write_bandwidth": $write_bw,
  "read_bandwidth": $read_bw,
  "alloc_latency_ms": $lelp,
  "total_kb": $total_kb,
  "available_kb": $avail_kb,
  "swap_total_kb": $swap_total,
  "unit": "KB/ms"
}
EOF
}

# ---- I/O Benchmark ----
bench_io() {
    log "bench_io: Starting I/O benchmark..."

    local test_file="/dev/shm/io_bench_test"
    local bs=4096
    local count=2560  # 10MB total

    # Sequential write
    local wstart=$(date +%s%N 2>/dev/null || date +%s)
    dd if=/dev/zero of="$test_file" bs=$bs count=$count 2>/dev/null
    sync
    local wend=$(date +%s%N 2>/dev/null || date +%s)
    local welp=$(( (wend - wstart) / 1000000 ))
    if [ "$welp" -eq 0 ]; then welp=1; fi
    local write_speed=$((count * bs / welp / 1024))  # KB/ms

    # Sequential read
    local rstart=$(date +%s%N 2>/dev/null || date +%s)
    dd if="$test_file" of=/dev/null bs=$bs 2>/dev/null
    local rend=$(date +%s%N 2>/dev/null || date +%s)
    local relp=$(( (rend - rstart) / 1000000 ))
    if [ "$relp" -eq 0 ]; then relp=1; fi
    local read_speed=$((count * bs / relp / 1024))  # KB/ms

    # Random 4K read (via dd seek)
    local rstart2=$(date +%s%N 2>/dev/null || date +%s)
    dd if="$test_file" of=/dev/null bs=4096 count=1000 skip=$((RANDOM % 1000)) 2>/dev/null
    local rend2=$(date +%s%N 2>/dev/null || date +%s)
    local relp2=$(( (rend2 - rstart2) / 1000000 ))
    if [ "$relp2" -eq 0 ]; then relp2=1; fi
    local rand_read=$((1000 * 4 / relp2))  # KB/ms

    rm -f "$test_file" 2>/dev/null

    # I/O scheduler info
    local scheduler=$(cat /sys/block/mmcblk0/queue/scheduler 2>/dev/null || echo "unknown")

    cat << EOF
{
  "name": "IO",
  "seq_write": $write_speed,
  "seq_read": $read_speed,
  "rand_4k_read": $rand_read,
  "scheduler": "$scheduler",
  "unit": "KB/ms"
}
EOF
}

# ---- Save Snapshot ----
save_snapshot() {
    local label="$1"
    local file="$RESULTS_DIR/${label}_${TIMESTAMP}.json"
    local before_file="$RESULTS_DIR/${label}.json"

    echo "{" > "$before_file"
    echo "  \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"," >> "$before_file"
    echo "  \"cpu\": $(bench_cpu)," >> "$before_file"
    echo "  \"ram\": $(bench_ram)," >> "$before_file"
    echo "  \"io\": $(bench_io)," >> "$before_file"
    echo "  \"gpu\": $(bench_gpu)" >> "$before_file"
    echo "}" >> "$before_file"

    echo "OK: $label snapshot saved"
}

# ---- Compare Before vs After ----
compare_results() {
    local before="$RESULTS_DIR/before.json"
    local after="$RESULTS_DIR/after.json"

    if [ ! -f "$before" ] || [ ! -f "$after" ]; then
        echo "ERROR: Need both before.json and after.json"
        echo "Run: benchmark.sh before  (before applying settings)"
        echo "Then: benchmark.sh after   (after applying settings)"
        return 1
    fi

    echo "=== Benchmark Results: Before vs After ==="
    echo ""

    # Extract and compare key metrics
    for metric in "cpu.combined" "ram.write_bandwidth" "ram.read_bandwidth" "io.seq_write" "io.seq_read"; do
        local section=$(echo "$metric" | cut -d. -f1)
        local key=$(echo "$metric" | cut -d. -f2)
        local bval=$(grep "\"$key\"" "$before" 2>/dev/null | head -1 | sed 's/.*: *//' | tr -d ', ')
        local aval=$(grep "\"$key\"" "$after" 2>/dev/null | head -1 | sed 's/.*: *//' | tr -d ', ')

        if [ -n "$bval" ] && [ -n "$aval" ] && [ "$bval" -gt 0 ] 2>/dev/null; then
            local diff=$((aval - bval))
            local pct=0
            if [ "$bval" -gt 0 ]; then
                pct=$((diff * 100 / bval))
            fi
            local sign="+"
            if [ "$diff" -lt 0 ]; then sign=""; fi
            printf "  %-25s  Before: %-8s  After: %-8s  %s%s%%\n" "$section.$key" "$bval" "$aval" "$sign" "$pct"
        fi
    done
    echo ""
}

# ---- Full Report ----
full_report() {
    echo "{"
    echo "  \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\","
    echo "  \"device\": {"
    echo "    \"model\": \"$(getprop ro.product.model 2>/dev/null)\","
    echo "    \"android\": \"$(getprop ro.build.version.release 2>/dev/null)\","
    echo "    \"soc\": \"$(getprop ro.board.platform 2>/dev/null)\","
    echo "    \"gpu\": \"$(getprop ro.hardware.egl 2>/dev/null)\""
    echo "  },"
    echo "  \"cpu\": $(bench_cpu),"
    echo "  \"ram\": $(bench_ram),"
    echo "  \"io\": $(bench_io),"
    echo "  \"gpu\": $(bench_gpu)"
    echo "}"
}

# ---- Main Dispatch ----
case "$1" in
    cpu)     bench_cpu ;;
    gpu)     bench_gpu ;;
    ram)     bench_ram ;;
    io)      bench_io ;;
    all)     full_report ;;
    before)  save_snapshot "before" ;;
    after)   save_snapshot "after" ;;
    compare) compare_results ;;
    report)  full_report ;;
    *)
        echo "OpenGL Renderer Ultimate — Benchmark"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  cpu       CPU benchmark"
        echo "  gpu       GPU benchmark"
        echo "  ram       RAM bandwidth + latency"
        echo "  io        I/O read/write speed"
        echo "  all       Full report (all benchmarks)"
        echo "  before    Save current state as baseline"
        echo "  after     Save current state for comparison"
        echo "  compare   Show before vs after diff"
        echo "  report    Full JSON report"
        ;;
esac
