#!/system/bin/sh
# ============================================================
# Dashboard Script — System Status Overview
# ============================================================
# Usage:
#   dashboard.sh       — Full JSON report
#   dashboard.sh quick — Quick status (minimal)
# ============================================================

MODDIR="${0%/*}/.."
. "$MODDIR/scripts/functions.sh" 2>/dev/null

# ---- Gather CPU Info ----
get_cpu() {
    local cores=$(nproc 2>/dev/null || echo 0)
    local max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || echo 0)
    local cur_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo 0)
    local min_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq 2>/dev/null || echo 0)
    local governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")

    # Online cores
    local online=0
    for i in $(seq 0 $((cores - 1))); do
        local on=$(cat /sys/devices/system/cpu/cpu${i}/online 2>/dev/null || echo 1)
        [ "$on" = "1" ] && online=$((online + 1))
    done

    # CPU usage (read /proc/stat)
    local cpu_line=$(head -1 /proc/stat 2>/dev/null)
    local cpu_idle=$(echo "$cpu_line" | awk '{print $5}')
    local cpu_total=$(echo "$cpu_line" | awk '{s=0; for(i=2;i<=NF;i++) s+=$i; print s}')
    local cpu_usage=0
    if [ -n "$cpu_total" ] && [ "$cpu_total" -gt 0 ] 2>/dev/null; then
        cpu_usage=$((100 * (cpu_total - cpu_idle) / cpu_total))
    fi

    # Temperature (try thermal zones)
    local temp=0
    for tz in /sys/class/thermal/thermal_zone*/temp; do
        local t=$(cat "$tz" 2>/dev/null)
        if [ -n "$t" ] && [ "$t" -gt "$temp" ] 2>/dev/null; then
            temp=$t
        fi
    done
    # Also try /sys/class/thermal/cooling_device*/cur_state or hwmon
    if [ "$temp" -eq 0 ]; then
        for hw in /sys/class/hwmon/hwmon*/temp1_input; do
            local t=$(cat "$hw" 2>/dev/null)
            if [ -n "$t" ] && [ "$t" -gt "$temp" ] 2>/dev/null; then
                temp=$t
            fi
        done
    fi

    # Load average
    local load=$(cat /proc/loadavg 2>/dev/null | awk '{print $1}')

    echo "\"cores\":$cores,\"online\":$online,\"max_freq\":$max_freq,\"cur_freq\":$cur_freq,\"min_freq\":$min_freq,\"governor\":\"$governor\",\"usage\":$cpu_usage,\"temp\":$temp,\"load\":\"$load\""
}

# ---- Gather GPU Info ----
get_gpu() {
    local vendor=$(getprop ro.hardware.egl 2>/dev/null || echo "unknown")
    local vk=$(getprop ro.hardware.vulkan 2>/dev/null || echo "unknown")
    local gpu_model="-"
    local gpu_clk=0
    local gpu_busy=0
    local gpu_max=0
    local gpu_gov="unknown"

    # Adreno KGSL
    local kgsl="/sys/class/kgsl/kgsl-3d0"
    if [ -d "$kgsl" ]; then
        gpu_model=$(cat "$kgsl/gpu_model" 2>/dev/null || echo "-")
        gpu_clk=$(cat "$kgsl/gpuclk" 2>/dev/null || echo 0)
        gpu_busy=$(cat "$kgsl/gpu_busy_percentage" 2>/dev/null || echo 0)
        gpu_max=$(cat "$kgsl/max_gpuclk" 2>/dev/null || echo 0)
        gpu_gov=$(cat "$kgsl/devfreq/governor" 2>/dev/null || echo "unknown")
    fi

    # Mali
    local mali=$(find /sys -maxdepth 4 -name "mali*" -type d 2>/dev/null | head -1)
    if [ -n "$mali" ] && [ -d "$mali/devfreq" ]; then
        gpu_clk=$(cat "$mali/devfreq/cur_freq" 2>/dev/null || echo 0)
        gpu_max=$(cat "$mali/devfreq/max_freq" 2>/dev/null || echo 0)
        gpu_gov=$(cat "$mali/devfreq/governor" 2>/dev/null || echo "unknown")
    fi

    echo "\"vendor\":\"$vendor\",\"vulkan\":\"$vk\",\"model\":\"$gpu_model\",\"clock\":$gpu_clk,\"busy\":$gpu_busy,\"max\":$gpu_max,\"governor\":\"$gpu_gov\""
}

# ---- Gather RAM Info ----
get_ram() {
    local total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local free=$(grep MemFree /proc/meminfo | awk '{print $2}')
    local avail=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local buffers=$(grep Buffers /proc/meminfo | awk '{print $2}')
    local cached=$(grep "^Cached" /proc/meminfo | awk '{print $2}')
    local swap_total=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
    local swap_free=$(grep SwapFree /proc/meminfo | awk '{print $2}')

    local used=0
    if [ -n "$total" ] && [ -n "$avail" ]; then
        used=$((total - avail))
    fi

    local usage_pct=0
    if [ -n "$total" ] && [ "$total" -gt 0 ] 2>/dev/null; then
        usage_pct=$((used * 100 / total))
    fi

    # ZRAM
    local zram_size=0
    for z in /sys/block/zram*/disksize; do
        local s=$(cat "$z" 2>/dev/null)
        if [ -n "$s" ]; then
            zram_size=$((zram_size + s))
        fi
    done

    echo "\"total\":$total,\"free\":$free,\"available\":$avail,\"buffers\":$buffers,\"cached\":$cached,\"used\":$used,\"usage_pct\":$usage_pct,\"swap_total\":$swap_total,\"swap_free\":$swap_free,\"zram_size\":$zram_size"
}

# ---- Gather Storage Info ----
get_storage() {
    local data_total=$(df /data 2>/dev/null | tail -1 | awk '{print $2}')
    local data_used=$(df /data 2>/dev/null | tail -1 | awk '{print $3}')
    local data_avail=$(df /data 2>/dev/null | tail -1 | awk '{print $4}')
    local data_pct=$(df /data 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')

    local system_total=$(df /system 2>/dev/null | tail -1 | awk '{print $2}')
    local system_used=$(df /system 2>/dev/null | tail -1 | awk '{print $3}')

    echo "\"data_total\":${data_total:-0},\"data_used\":${data_used:-0},\"data_avail\":${data_avail:-0},\"data_pct\":${data_pct:-0},\"system_total\":${system_total:-0},\"system_used\":${system_used:-0}"
}

# ---- Gather Battery Info ----
get_battery() {
    local level=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo -1)
    local status=$(cat /sys/class/power_supply/battery/status 2>/dev/null || echo "unknown")
    local temp=$(cat /sys/class/power_supply/battery/temp 2>/dev/null || echo 0)
    local voltage=$(cat /sys/class/power_supply/battery/voltage_now 2>/dev/null || echo 0)
    local health=$(cat /sys/class/power_supply/battery/health 2>/dev/null || echo "unknown")
    local tech=$(cat /sys/class/power_supply/battery/technology 2>/dev/null || echo "unknown")

    # Current in uA
    local current=$(cat /sys/class/power_supply/battery/current_now 2>/dev/null || echo 0)

    echo "\"level\":$level,\"status\":\"$status\",\"temp\":$temp,\"voltage\":$voltage,\"health\":\"$health\",\"technology\":\"$tech\",\"current\":$current"
}

# ---- Gather Network Info ----
get_network() {
    local wifi_state=$(dumpsys wifi 2>/dev/null | grep "Wi-Fi is" | head -1 | awk '{print $NF}' || echo "unknown")
    local wifi_ssid=$(dumpsys wifi 2>/dev/null | grep "mWifiInfo" | head -1 | sed 's/.*SSID: //' | sed 's/,.*//' || echo "-")
    local ip=$(ip route get 1.1.1.1 2>/dev/null | head -1 | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' || echo "-")
    local mac=$(cat /sys/class/net/wlan0/address 2>/dev/null || echo "-")
    local rx=$(cat /sys/class/net/wlan0/statistics/rx_bytes 2>/dev/null || echo 0)
    local tx=$(cat /sys/class/net/wlan0/statistics/tx_bytes 2>/dev/null || echo 0)
    local tcp_cong=$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo "unknown")

    echo "\"wifi\":\"$wifi_state\",\"ssid\":\"$wifi_ssid\",\"ip\":\"$ip\",\"mac\":\"$mac\",\"rx\":$rx,\"tx\":$tx,\"tcp_congestion\":\"$tcp_cong\""
}

# ---- Gather Thermal Info ----
get_thermal() {
    local zones=0
    local max_temp=0
    local hottest_zone=""
    local temps=""

    for tz in /sys/class/thermal/thermal_zone*; do
        [ -d "$tz" ] || continue
        zones=$((zones + 1))
        local t=$(cat "$tz/temp" 2>/dev/null || echo 0)
        local name=$(cat "$tz/type" 2>/dev/null || echo "zone_$zones")
        if [ -n "$t" ] && [ "$t" -gt "$max_temp" ] 2>/dev/null; then
            max_temp=$t
            hottest_zone="$name"
        fi
    done

    echo "\"zones\":$zones,\"max_temp\":$max_temp,\"hottest\":\"$hottest_zone\""
}

# ---- Module Status ----
get_module_status() {
    local gamemode="OFF"
    local game_pkg=""
    local active_profile="None"

    if [ -f "$CONF_DIR/gamemode_active" ]; then
        gamemode="ACTIVE"
        game_pkg=$(head -1 "$CONF_DIR/gamemode_active" 2>/dev/null)
    fi

    if [ -f "$CONF_DIR/active_profile" ]; then
        active_profile=$(cat "$CONF_DIR/active_profile" 2>/dev/null)
    fi

    local hwui=$(getprop debug.hwui.renderer 2>/dev/null || echo "-")
    local re=$(getprop debug.renderengine.backend 2>/dev/null || echo "-")
    local anim=$(getprop window_animation_scale 2>/dev/null || echo "-")

    echo "\"gamemode\":\"$gamemode\",\"game_pkg\":\"$game_pkg\",\"active_profile\":\"$active_profile\",\"hwui\":\"$hwui\",\"renderengine\":\"$re\",\"animation\":\"$anim\""
}

# ---- Device Info ----
get_device() {
    local model=$(getprop ro.product.model 2>/dev/null || echo "-")
    local brand=$(getprop ro.product.brand 2>/dev/null || echo "-")
    local device=$(getprop ro.product.device 2>/dev/null || echo "-")
    local android=$(getprop ro.build.version.release 2>/dev/null || echo "-")
    local sdk=$(getprop ro.build.version.sdk 2>/dev/null || echo 0)
    local soc=$(getprop ro.board.platform 2>/dev/null || echo "-")
    local kernel=$(uname -r 2>/dev/null || echo "-")
    local uptime=$(cat /proc/uptime 2>/dev/null | awk '{print $1}' | cut -d. -f1 || echo 0)

    echo "\"model\":\"$model\",\"brand\":\"$brand\",\"device\":\"$device\",\"android\":\"$android\",\"sdk\":$sdk,\"soc\":\"$soc\",\"kernel\":\"$kernel\",\"uptime\":$uptime"
}

# ---- Full Report ----
full_report() {
    echo "{"
    echo "  \"device\": {$(get_device)},"
    echo "  \"cpu\": {$(get_cpu)},"
    echo "  \"gpu\": {$(get_gpu)},"
    echo "  \"ram\": {$(get_ram)},"
    echo "  \"storage\": {$(get_storage)},"
    echo "  \"battery\": {$(get_battery)},"
    echo "  \"network\": {$(get_network)},"
    echo "  \"thermal\": {$(get_thermal)},"
    echo "  \"module\": {$(get_module_status)}"
    echo "}"
}

# ---- Main ----
case "$1" in
    quick)
        echo "Device: $(getprop ro.product.model 2>/dev/null)"
        echo "Android: $(getprop ro.build.version.release 2>/dev/null)"
        echo "CPU: $(nproc 2>/dev/null) cores @ $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null | awk '{printf "%.0f MHz", $1/1000}')"
        echo "RAM: $(grep MemAvailable /proc/meminfo | awk '{printf "%.0f MB", $2/1024}') free / $(grep MemTotal /proc/meminfo | awk '{printf "%.0f MB", $2/1024}') total"
        echo "Battery: $(cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo ?)%"
        ;;
    *)
        full_report
        ;;
esac
