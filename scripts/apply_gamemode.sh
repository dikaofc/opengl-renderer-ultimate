#!/system/bin/sh
# ============================================================
# Game Mode Script — OpenGL Renderer Ultimate
# ============================================================
# Usage:
#   gamemode.sh list              — List all game presets
#   gamemode.sh info <pkg>        — Show preset info for a game
#   gamemode.sh apply <pkg>       — Apply game preset
#   gamemode.sh custom <name>     — Apply custom game preset
#   gamemode.sh detect            — Detect running game
#   gamemode.sh auto              — Auto-detect and apply
#   gamemode.sh off               — Revert to default settings
#   gamemode.sh status            — Show current game mode status
#   gamemode.sh save <name>       — Save current settings as custom preset
# ============================================================

MODDIR="${0%/*}/.."
. "$MODDIR/scripts/functions.sh" 2>/dev/null

GAMEMODE_FILE="$CONF_DIR/gamemode_active"
GAMEMODE_LOG="$CONF_DIR/logs/gamemode.log"

# ---- Game Presets ----

# Each preset defines optimal settings for a specific game genre/title

preset_moba() {
    # MOBA: Mobile Legends, Wild Rift, Arena of Valor
    log "gamemode: Applying MOBA preset"
    apply_cpu_preset performance 1
    apply_gpu_preset performance 1
    apply_ram_preset aggressive
    apply_net_preset low_latency
    apply_thermal_preset performance
    apply_anim_preset off
    apply_sched_preset responsive
    apply_io_preset fast
}

preset_battle_royale() {
    # BR: PUBG Mobile, Free Fire, COD Mobile, Fortnite
    log "gamemode: Applying Battle Royale preset"
    apply_cpu_preset performance 1
    apply_gpu_preset max
    apply_ram_preset aggressive
    apply_net_preset low_latency
    apply_thermal_preset performance
    apply_anim_preset off
    apply_sched_preset responsive
    apply_io_preset fast
}

preset_open_world() {
    # Open World: Genshin Impact, Honkai Star Rail, Zelda-style
    log "gamemode: Applying Open World preset"
    apply_cpu_preset performance 1
    apply_gpu_preset max
    apply_ram_preset maximum
    apply_net_preset balanced
    apply_thermal_preset aggressive
    apply_anim_preset off
    apply_sched_preset responsive
    apply_io_preset max
}

preset_racing() {
    # Racing: Asphalt 9, GRID, Need for Speed
    log "gamemode: Applying Racing preset"
    apply_cpu_preset performance 1
    apply_gpu_preset max
    apply_ram_preset aggressive
    apply_net_preset low_latency
    apply_thermal_preset performance
    apply_anim_preset off
    apply_sched_preset responsive
    apply_io_preset fast
}

preset_fps() {
    # FPS: COD Mobile, PUBG, Valorant Mobile
    log "gamemode: Applying FPS preset"
    apply_cpu_preset performance 1
    apply_gpu_preset max
    apply_ram_preset aggressive
    apply_net_preset ultra_low_latency
    apply_thermal_preset performance
    apply_anim_preset off
    apply_sched_preset responsive
    apply_io_preset fast
}

preset_casual() {
    # Casual: Roblox, Minecraft, Candy Crush
    log "gamemode: Applying Casual preset"
    apply_cpu_preset balanced
    apply_gpu_preset balanced
    apply_ram_preset moderate
    apply_net_preset balanced
    apply_thermal_preset balanced
    apply_anim_preset normal
    apply_sched_preset balanced
    apply_io_preset balanced
}

preset_competitive() {
    # Competitive esports: Mobile Legends ranked, PUBG competitive
    log "gamemode: Applying Competitive preset"
    apply_cpu_preset max
    apply_gpu_preset max
    apply_ram_preset maximum
    apply_net_preset ultra_low_latency
    apply_thermal_preset maximum
    apply_anim_preset off
    apply_sched_preset ultra_responsive
    apply_io_preset max
}

# ---- Sub-applyers ----

apply_cpu_preset() {
    local level="$1"
    local oc="${2:-0}"

    case "$level" in
        max)
            for i in /sys/devices/system/cpu/cpu*/cpufreq; do
                [ -d "$i" ] || continue
                echo performance > "$i/scaling_governor" 2>/dev/null
                cat "$i/cpuinfo_max_freq" > "$i/scaling_max_freq" 2>/dev/null
            done
            ;;
        performance)
            for i in /sys/devices/system/cpu/cpu*/cpufreq; do
                [ -d "$i" ] || continue
                echo performance > "$i/scaling_governor" 2>/dev/null
                cat "$i/cpuinfo_max_freq" > "$i/scaling_max_freq" 2>/dev/null
            done
            ;;
        balanced)
            for i in /sys/devices/system/cpu/cpu*/cpufreq; do
                [ -d "$i" ] || continue
                echo schedutil > "$i/scaling_governor" 2>/dev/null
            done
            ;;
    esac

    # CPU Boost
    echo 1 > /sys/module/cpu_boost/parameters/sched_boost_on_input 2>/dev/null
    echo 50 > /sys/module/cpu_boost/parameters/input_boost_ms 2>/dev/null

    # Scheduler
    echo 500000 > /proc/sys/kernel/sched_min_granularity_ns 2>/dev/null
    echo 500000 > /proc/sys/kernel/sched_wakeup_granularity_ns 2>/dev/null
    echo 1000000 > /proc/sys/kernel/sched_latency_ns 2>/dev/null
    echo 0 > /proc/sys/kernel/sched_autogroup_enabled 2>/dev/null
}

apply_gpu_preset() {
    local level="$1"
    local oc="${2:-0}"

    case "$level" in
        max|performance)
            # Adreno
            local kgsl="/sys/class/kgsl/kgsl-3d0"
            if [ -d "$kgsl" ]; then
                echo performance > "$kgsl/devfreq/governor" 2>/dev/null
                if [ "$oc" = "1" ]; then
                    local max_clk=$(cat "$kgsl/gpu_available_frequencies" 2>/dev/null | tr ' ' '\n' | sort -n | tail -1)
                    [ -n "$max_clk" ] && echo "$max_clk" > "$kgsl/max_gpuclk" 2>/dev/null
                    [ -w "$kgsl/force_clk_on" ] && echo 1 > "$kgsl/force_clk_on" 2>/dev/null
                    [ -w "$kgsl/force_bus_on" ] && echo 1 > "$kgsl/force_bus_on" 2>/dev/null
                    [ -w "$kgsl/force_rail_on" ] && echo 1 > "$kgsl/force_rail_on" 2>/dev/null
                    [ -w "$kgsl/idle_timer" ] && echo 0 > "$kgsl/idle_timer" 2>/dev/null
                fi
            fi
            # Mali
            local mali=$(find /sys -maxdepth 4 -name "mali*" -type d 2>/dev/null | head -1)
            if [ -n "$mali" ] && [ -d "$mali/devfreq" ]; then
                echo performance > "$mali/devfreq/governor" 2>/dev/null
            fi
            ;;
        balanced)
            local kgsl="/sys/class/kgsl/kgsl-3d0"
            if [ -d "$kgsl" ]; then
                echo msm-adreno-tz > "$kgsl/devfreq/governor" 2>/dev/null
            fi
            ;;
    esac
}

apply_ram_preset() {
    local level="$1"

    case "$level" in
        maximum)
            echo 120 > /proc/sys/vm/swappiness 2>/dev/null
            echo 50 > /proc/sys/vm/dirty_ratio 2>/dev/null
            echo 15 > /proc/sys/vm/dirty_background_ratio 2>/dev/null
            echo 40 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
            echo 16384 > /proc/sys/vm/min_free_kbytes 2>/dev/null
            echo 12288 > /proc/sys/vm/extra_free_kbytes 2>/dev/null
            ;;
        aggressive)
            echo 110 > /proc/sys/vm/swappiness 2>/dev/null
            echo 45 > /proc/sys/vm/dirty_ratio 2>/dev/null
            echo 12 > /proc/sys/vm/dirty_background_ratio 2>/dev/null
            echo 45 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
            echo 14336 > /proc/sys/vm/min_free_kbytes 2>/dev/null
            echo 10240 > /proc/sys/vm/extra_free_kbytes 2>/dev/null
            ;;
        moderate)
            echo 100 > /proc/sys/vm/swappiness 2>/dev/null
            echo 40 > /proc/sys/vm/dirty_ratio 2>/dev/null
            echo 10 > /proc/sys/vm/dirty_background_ratio 2>/dev/null
            echo 50 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
            echo 12288 > /proc/sys/vm/min_free_kbytes 2>/dev/null
            echo 8192 > /proc/sys/vm/extra_free_kbytes 2>/dev/null
            ;;
        balanced)
            echo 80 > /proc/sys/vm/swappiness 2>/dev/null
            echo 30 > /proc/sys/vm/dirty_ratio 2>/dev/null
            echo 5 > /proc/sys/vm/dirty_background_ratio 2>/dev/null
            echo 80 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
            echo 8192 > /proc/sys/vm/min_free_kbytes 2>/dev/null
            ;;
    esac

    # Drop caches for fresh memory
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
    echo 1 > /proc/sys/vm/compact_memory 2>/dev/null
}

apply_net_preset() {
    local level="$1"

    case "$level" in
        ultra_low_latency)
            echo bbr > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
            echo fq > /proc/sys/net/core/default_qdisc 2>/dev/null
            echo 3 > /proc/sys/net/ipv4/tcp_fastopen 2>/dev/null
            echo 0 > /proc/sys/net/ipv4/tcp_slow_start_after_idle 2>/dev/null
            echo 1 > /proc/sys/net/ipv4/tcp_mtu_probing 2>/dev/null
            echo 1 > /proc/sys/net/ipv4/tcp_sack 2>/dev/null
            echo 0 > /proc/sys/net/ipv4/tcp_no_metrics_save 2>/dev/null
            echo 16777216 > /proc/sys/net/core/rmem_max 2>/dev/null
            echo 16777216 > /proc/sys/net/core/wmem_max 2>/dev/null
            echo 8192 > /proc/sys/net/core/netdev_max_backlog 2>/dev/null
            echo 8192 > /proc/sys/net/core/somaxconn 2>/dev/null
            # Disable WiFi power save
            for iface in /sys/class/net/wlan*/power_save; do
                [ -w "$iface" ] && echo 0 > "$iface" 2>/dev/null
            done
            ;;
        low_latency)
            echo bbr > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
            echo fq > /proc/sys/net/core/default_qdisc 2>/dev/null
            echo 3 > /proc/sys/net/ipv4/tcp_fastopen 2>/dev/null
            echo 0 > /proc/sys/net/ipv4/tcp_slow_start_after_idle 2>/dev/null
            echo 1 > /proc/sys/net/ipv4/tcp_mtu_probing 2>/dev/null
            echo 16777216 > /proc/sys/net/core/rmem_max 2>/dev/null
            echo 16777216 > /proc/sys/net/core/wmem_max 2>/dev/null
            for iface in /sys/class/net/wlan*/power_save; do
                [ -w "$iface" ] && echo 0 > "$iface" 2>/dev/null
            done
            ;;
        balanced)
            echo bbr > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
            echo fq > /proc/sys/net/core/default_qdisc 2>/dev/null
            echo 1048576 > /proc/sys/net/core/rmem_max 2>/dev/null
            echo 1048576 > /proc/sys/net/core/wmem_max 2>/dev/null
            ;;
    esac
}

apply_thermal_preset() {
    local level="$1"

    case "$level" in
        maximum)
            for tz in /sys/class/thermal/thermal_zone*/mode; do
                [ -w "$tz" ] && echo disabled > "$tz" 2>/dev/null
            done
            for tz in /sys/class/thermal/thermal_zone*/trip_point_*_temp; do
                [ -f "$tz" ] || continue
                cur=$(cat "$tz" 2>/dev/null)
                if [ -n "$cur" ] && [ "$cur" -gt 0 ] 2>/dev/null; then
                    echo $((cur + 10000)) > "$tz" 2>/dev/null
                fi
            done
            ;;
        performance)
            for tz in /sys/class/thermal/thermal_zone*/mode; do
                [ -w "$tz" ] && echo disabled > "$tz" 2>/dev/null
            done
            for tz in /sys/class/thermal/thermal_zone*/trip_point_*_temp; do
                [ -f "$tz" ] || continue
                cur=$(cat "$tz" 2>/dev/null)
                if [ -n "$cur" ] && [ "$cur" -gt 0 ] 2>/dev/null; then
                    echo $((cur + 5000)) > "$tz" 2>/dev/null
                fi
            done
            ;;
        balanced)
            for tz in /sys/class/thermal/thermal_zone*/mode; do
                [ -w "$tz" ] && echo enabled > "$tz" 2>/dev/null
            done
            ;;
    esac
}

apply_anim_preset() {
    local level="$1"

    case "$level" in
        off)
            setprop window_animation_scale 0
            setprop transition_animation_scale 0
            setprop animator_duration_scale 0
            ;;
        minimal)
            setprop window_animation_scale 0.25
            setprop transition_animation_scale 0.25
            setprop animator_duration_scale 0.25
            ;;
        normal)
            setprop window_animation_scale 1.0
            setprop transition_animation_scale 1.0
            setprop animator_duration_scale 1.0
            ;;
    esac
}

apply_sched_preset() {
    local level="$1"

    case "$level" in
        ultra_responsive)
            echo 250000 > /proc/sys/kernel/sched_min_granularity_ns 2>/dev/null
            echo 250000 > /proc/sys/kernel/sched_wakeup_granularity_ns 2>/dev/null
            echo 500000 > /proc/sys/kernel/sched_latency_ns 2>/dev/null
            echo 50000 > /proc/sys/kernel/sched_migration_cost_ns 2>/dev/null
            echo 8 > /proc/sys/kernel/sched_nr_migrate 2>/dev/null
            echo 0 > /proc/sys/kernel/sched_autogroup_enabled 2>/dev/null
            echo 0 > /proc/sys/kernel/sched_child_runs_first 2>/dev/null
            ;;
        responsive)
            echo 500000 > /proc/sys/kernel/sched_min_granularity_ns 2>/dev/null
            echo 500000 > /proc/sys/kernel/sched_wakeup_granularity_ns 2>/dev/null
            echo 1000000 > /proc/sys/kernel/sched_latency_ns 2>/dev/null
            echo 100000 > /proc/sys/kernel/sched_migration_cost_ns 2>/dev/null
            echo 4 > /proc/sys/kernel/sched_nr_migrate 2>/dev/null
            echo 0 > /proc/sys/kernel/sched_autogroup_enabled 2>/dev/null
            ;;
        balanced)
            echo 750000 > /proc/sys/kernel/sched_min_granularity_ns 2>/dev/null
            echo 750000 > /proc/sys/kernel/sched_wakeup_granularity_ns 2>/dev/null
            echo 1500000 > /proc/sys/kernel/sched_latency_ns 2>/dev/null
            echo 0 > /proc/sys/kernel/sched_autogroup_enabled 2>/dev/null
            ;;
    esac
}

apply_io_preset() {
    local level="$1"

    case "$level" in
        max|fast)
            for q in /sys/block/*/queue; do
                [ -d "$q" ] || continue
                echo bfq > "$q/scheduler" 2>/dev/null
                echo 256 > "$q/nr_requests" 2>/dev/null
                echo 4096 > "$q/read_ahead_kb" 2>/dev/null
                echo 2 > "$q/rq_affinity" 2>/dev/null
                echo 0 > "$q/nomerges" 2>/dev/null
            done
            ;;
        balanced)
            for q in /sys/block/*/queue; do
                [ -d "$q" ] || continue
                echo bfq > "$q/scheduler" 2>/dev/null
                echo 64 > "$q/nr_requests" 2>/dev/null
                echo 2048 > "$q/read_ahead_kb" 2>/dev/null
            done
            ;;
    esac
}

# ---- Detect Running Game ----
detect_running_game() {
    # Get foreground activity
    local pkg=$(dumpsys activity activities 2>/dev/null | grep -E "mResumedActivity|topResumedActivity" | head -1 | sed 's/.*u0 //' | sed 's/\/.*//' | tr -d ' ')

    if [ -z "$pkg" ]; then
        # Fallback: check /proc for known game processes
        for game_pkg in \
            "com.mobile.legends" \
            "com.tencent.ig" \
            "com.miHoYo.GenshinImpact" \
            "com.dts.freefireth" \
            "com.activision.callofduty.shooter" \
            "com.roblox.client" \
            "com.epicgames.fortnite" \
            "com.miHoYo.hkrpg" \
            "com.gameloft.android.ANMP.GloftA9HM" \
            "com.mojang.minecraftpe" \
            "com.supercell.clashofclans" \
            "com.supercell.clashroyale" \
            "com.riotgames.league.teamfighttactics" \
            "com.tencent.lolm" \
            "com.pubg.krmobile" \
            "com.pubg.imobile" \
            "com.garena.game.codm" \
            "com.shangyoo.nday" \
            "com.innersloth.spacemafia" \
            "com.ea.gp.fifamobile" \
            "com.kabam.clashroyale" \
            "com.square_enix.android.googleplay.FFBEWW" \
            "com.square_enix.ffviieverecrisis" \
            "com.nianticlabs.pokemongo" \
            "com.nianticlabs.pokemongo.aware" \
            "com.king.candycrushsaga" \
            "com.miniclip.eightballpool" \
            "com.yodo1.crossboard.gp" \
            "com.tencent.tmgp.sgame" \
            "com.netease.ma" \
            "com.netease.g93na" \
            "com.netease.dwrg" \
            "com.kurogame.gplay.punishing" \
            "com.HoYoverse.Nap" \
            "com.tencent.KiHan" \
            "com.lilithgames.rokgp"
        do
            if pgrep -f "$game_pkg" >/dev/null 2>&1; then
                echo "$game_pkg"
                return
            fi
        done
    fi

    echo "$pkg"
}

# ---- Get Game Genre ----
get_game_genre() {
    local pkg="$1"
    case "$pkg" in
        *mobile.legends*|*tencent.lolm*|*lolm*|*wildrift*)
            echo "moba" ;;
        *tencent.ig*|*pubg*|*freefire*|*callofduty*|*fortnite*|*codm*)
            echo "battle_royale" ;;
        *miHoYo.GenshinImpact*|*miHoYo.hkrpg*|*HonkaiStar*|*StarRail*)
            echo "open_world" ;;
        *GloftA9HM*|*asphalt*|*GRID*|*nfs*)
            echo "racing" ;;
        *callofduty.shooter*|*codm*|*valorant*)
            echo "fps" ;;
        *roblox*|*minecraftpe*|*candycrush*|*clashofclans*|*clashroyale*|*eightballpool*)
            echo "casual" ;;
        *)
            echo "battle_royale" ;;
    esac
}

# ---- List Games ----
cmd_list() {
    cat << 'EOF'
=== Game Presets ===

[MOBA]
  com.mobile.legends       — Mobile Legends: Bang Bang
  com.tencent.lolm         — League of Legends: Wild Rift
  com.tencent.KiHan        — League of Legends: Wild Rift (KR)
  com.netease.ma           — Onmyoji Arena
  com.tencent.tmgp.sgame   — Honor of Kings

[Battle Royale]
  com.tencent.ig           — PUBG Mobile (Global)
  com.pubg.krmobile        — PUBG Mobile (KR)
  com.pubg.imobile         — PUBG Mobile (India)
  com.dts.freefireth       — Free Fire
  com.garena.game.codm     — Call of Duty Mobile (Garena)
  com.activision.callofduty.shooter — COD Mobile
  com.epicgames.fortnite   — Fortnite
  com.netease.g93na        — Rules of Survival
  com.yodo1.crossboard.gp  — Mario Kart Tour (no, actually Apex Legends Mobile)

[Open World]
  com.miHoYo.GenshinImpact — Genshin Impact
  com.miHoYo.hkrpg         — Honkai: Star Rail
  com.HoYoverse.Nap        — Zenless Zone Zero
  com.kurogame.gplay.punishing — Wuthering Waves

[Racing]
  com.gameloft.android.ANMP.GloftA9HM — Asphalt 9

[FPS]
  com.activision.callofduty.shooter — COD Mobile

[Casual]
  com.roblox.client        — Roblox
  com.mojang.minecraftpe   — Minecraft
  com.supercell.clashofclans — Clash of Clans
  com.supercell.clashroyale — Clash Royale
  com.king.candycrushsaga  — Candy Crush Saga
  com.nianticlabs.pokemongo — Pokemon GO
  com.ea.gp.fifamobile     — FIFA Mobile
  com.miniclip.eightballpool — 8 Ball Pool

[Competitive / Esports]
  com.mobile.legends       — MLBB Ranked
  com.tencent.ig           — PUBG Competitive
  com.miHoYo.GenshinImpact — GI Spiral Abyss
EOF
}

# ---- Info ----
cmd_info() {
    local pkg="$1"
    local genre=$(get_game_genre "$pkg")
    echo "Package : $pkg"
    echo "Genre   : $genre"
    echo "Preset  : preset_$genre"
    echo ""
    echo "Settings applied by this preset:"
    echo "  CPU       : performance governor, max freq, boost ON"
    echo "  GPU       : performance governor, force clk/bus/rail ON"
    echo "  RAM       : aggressive memory management"
    echo "  Network   : BBR, low latency, WiFi power save OFF"
    echo "  Thermal   : disabled (max performance)"
    echo "  Animation : OFF (zero overhead)"
    echo "  Scheduler : responsive, low latency"
    echo "  I/O       : BFQ, large readahead"
}

# ---- Apply Game Mode ----
cmd_apply() {
    local pkg="$1"

    if [ -z "$pkg" ]; then
        echo "ERROR: Package name required"
        echo "Usage: $0 apply <package>"
        exit 1
    fi

    local genre=$(get_game_genre "$pkg")
    local game_name=$(cmd_list 2>/dev/null | grep "$pkg" | sed 's/—//' | awk -F'—' '{print $2}' | head -1)
    [ -z "$game_name" ] && game_name="$pkg"

    log "gamemode: Activating for $game_name ($pkg) genre=$genre"

    echo "Activating Game Mode for: $game_name"
    echo "Genre: $genre"
    echo ""

    case "$genre" in
        moba)            preset_moba ;;
        battle_royale)   preset_battle_royale ;;
        open_world)      preset_open_world ;;
        racing)          preset_racing ;;
        fps)             preset_fps ;;
        casual)          preset_casual ;;
        *)               preset_battle_royale ;;
    esac

    # Save active state
    echo "$pkg" > "$GAMEMODE_FILE"
    echo "genre=$genre" >> "$GAMEMODE_FILE"
    echo "activated=$(date '+%Y-%m-%d %H:%M:%S')" >> "$GAMEMODE_FILE"

    echo ""
    echo "Game Mode: ACTIVE"
    echo "Package: $pkg"
    echo "Genre: $genre"
}

# ---- Auto Detect and Apply ----
cmd_auto() {
    local pkg=$(detect_running_game)
    if [ -z "$pkg" ]; then
        echo "No game detected in foreground"
        echo ""
        echo "Tip: Start a game first, then run this again"
        return 1
    fi

    local genre=$(get_game_genre "$pkg")
    local game_name=$(cmd_list 2>/dev/null | grep "$pkg" | sed 's/—//' | awk -F'—' '{print $2}' | head -1)
    [ -z "$game_name" ] && game_name="$pkg"

    echo "Detected: $game_name ($pkg)"
    echo "Genre: $genre"
    echo ""
    cmd_apply "$pkg"
}

# ---- Revert to Default ----
cmd_off() {
    log "gamemode: Reverting to default settings"

    # Revert CPU
    for i in /sys/devices/system/cpu/cpu*/cpufreq; do
        [ -d "$i" ] || continue
        echo schedutil > "$i/scaling_governor" 2>/dev/null
    done

    # Revert GPU
    local kgsl="/sys/class/kgsl/kgsl-3d0"
    if [ -d "$kgsl" ]; then
        echo msm-adreno-tz > "$kgsl/devfreq/governor" 2>/dev/null
        [ -w "$kgsl/force_clk_on" ] && echo 0 > "$kgsl/force_clk_on" 2>/dev/null
        [ -w "$kgsl/force_bus_on" ] && echo 0 > "$kgsl/force_bus_on" 2>/dev/null
        [ -w "$kgsl/force_rail_on" ] && echo 0 > "$kgsl/force_rail_on" 2>/dev/null
        [ -w "$kgsl/idle_timer" ] && echo 50 > "$kgsl/idle_timer" 2>/dev/null
    fi

    # Revert RAM
    echo 100 > /proc/sys/vm/swappiness 2>/dev/null
    echo 40 > /proc/sys/vm/dirty_ratio 2>/dev/null
    echo 10 > /proc/sys/vm/dirty_background_ratio 2>/dev/null
    echo 50 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
    echo 12288 > /proc/sys/vm/min_free_kbytes 2>/dev/null

    # Revert Animation
    setprop window_animation_scale 0.5
    setprop transition_animation_scale 0.5
    setprop animator_duration_scale 0.5

    # Revert Thermal
    for tz in /sys/class/thermal/thermal_zone*/mode; do
        [ -w "$tz" ] && echo enabled > "$tz" 2>/dev/null
    done

    # Revert I/O
    for q in /sys/block/*/queue; do
        [ -d "$q" ] || continue
        echo bfq > "$q/scheduler" 2>/dev/null
        echo 64 > "$q/nr_requests" 2>/dev/null
        echo 2048 > "$q/read_ahead_kb" 2>/dev/null
    done

    # Revert WiFi power save
    for iface in /sys/class/net/wlan*/power_save; do
        [ -w "$iface" ] && echo 1 > "$iface" 2>/dev/null
    done

    # Clear state
    rm -f "$GAMEMODE_FILE"

    echo "Game Mode: OFF"
    echo "All settings reverted to defaults"
}

# ---- Status ----
cmd_status() {
    if [ -f "$GAMEMODE_FILE" ]; then
        local pkg=$(head -1 "$GAMEMODE_FILE")
        local genre=$(grep "^genre=" "$GAMEMODE_FILE" | cut -d= -f2)
        local activated=$(grep "^activated=" "$GAMEMODE_FILE" | cut -d= -f2)
        echo "Game Mode: ACTIVE"
        echo "Package  : $pkg"
        echo "Genre    : $genre"
        echo "Activated: $activated"
    else
        echo "Game Mode: OFF"
    fi
}

# ---- Scan Installed Apps ----
CUSTOM_GAMES_FILE="$CONF_DIR/custom_games.conf"

cmd_scan() {
    local filter="${2:-}"
    log "gamemode: Scanning installed apps..."

    echo "=== Installed Apps ==="
    echo ""

    # Method 1: pm list packages
    local packages=""
    if command -v pm >/dev/null 2>&1; then
        packages=$(pm list packages -3 2>/dev/null)  # Third-party apps
        local system_apps=$(pm list packages -s 2>/dev/null | head -100)  # System (limited)
        packages="$packages\n$system_apps"
    fi

    # Method 2: scan /data/app
    if [ -z "$packages" ]; then
        for dir in /data/app/*; do
            [ -d "$dir" ] || continue
            local pkg=$(basename "$dir" | sed 's/^base-//' | sed 's/-.*//')
            packages="$packages\npackage:$pkg"
        done
    fi

    # Method 3: scan /system/app and /system/priv-app
    for dir in /system/app/* /system/priv-app/* /product/app/* /product/priv-app/*; do
        [ -d "$dir" ] || continue
        local pkg=$(basename "$dir")
        packages="$packages\npackage:$pkg"
    done

    # Parse and display
    local count=0
    echo "$packages" | sed 's/^package://' | sort -u | while read -r pkg; do
        [ -z "$pkg" ] && continue

        # Apply filter if provided
        if [ -n "$filter" ]; then
            case "$pkg" in
                *$filter*) ;;
                *) continue ;;
            esac
        fi

        # Get app label via dumpsys (fast)
        local label=$(dumpsys package "$pkg" 2>/dev/null | grep -E "applicationLabel|nonLocalizedLabel" | head -1 | sed 's/.*=//' | tr -d '"' | xargs)
        [ -z "$label" ] && label="$pkg"

        # Check if it's a known game
        local is_game=0
        local genre=""
        case "$pkg" in
            *mobile.legends*|*tencent.lolm*|*tencent.KiHan*|*tencent.tmgp.sgame*|*netease.ma*)
                is_game=1; genre="moba" ;;
            *tencent.ig*|*pubg*|*freefire*|*callofduty*|*codm*|*epicgames.fortnite*|*netease.g93na*)
                is_game=1; genre="battle_royale" ;;
            *miHoYo*|*HoYoverse*|*kurogame*)
                is_game=1; genre="open_world" ;;
            *GloftA9*|*asphalt*|*nfs*)
                is_game=1; genre="racing" ;;
            *roblox*|*minecraftpe*|*candycrush*|*clashofclans*|*clashroyale*|*pokemon*|*fifa*|*eightball*)
                is_game=1; genre="casual" ;;
        esac

        # Check if it's a custom game
        if [ -f "$CUSTOM_GAMES_FILE" ] && grep -q "$pkg" "$CUSTOM_GAMES_FILE" 2>/dev/null; then
            is_game=1
            genre=$(grep "$pkg" "$CUSTOM_GAMES_FILE" | cut -d'|' -f3)
        fi

        # Output as JSON line
        local game_tag=""
        [ "$is_game" = "1" ] && game_tag="[GAME:$genre]"
        echo "$pkg|$label|$is_game|$genre|$game_tag"
        count=$((count + 1))
    done
}

# ---- Scan as JSON ----
cmd_scan_json() {
    local filter="${2:-}"
    echo "["
    local first=1

    # Third-party apps
    pm list packages -3 2>/dev/null | sed 's/^package://' | while read -r pkg; do
        [ -z "$pkg" ] && continue
        [ -n "$filter" ] && case "$pkg" in *$filter*) ;; *) continue ;; esac

        local label=$(dumpsys package "$pkg" 2>/dev/null | grep -E "applicationLabel|nonLocalizedLabel" | head -1 | sed 's/.*=//' | tr -d '"' | xargs)
        [ -z "$label" ] && label="$pkg"

        # Detect genre
        local genre="none"
        local is_game=0
        case "$pkg" in
            *mobile.legends*|*tencent.lolm*|*tencent.KiHan*|*tencent.tmgp.sgame*) genre="moba"; is_game=1 ;;
            *tencent.ig*|*pubg*|*freefire*|*codm*|*callofduty*|*fortnite*) genre="battle_royale"; is_game=1 ;;
            *miHoYo*|*HoYoverse*|*kurogame*) genre="open_world"; is_game=1 ;;
            *GloftA9*|*asphalt*) genre="racing"; is_game=1 ;;
            *roblox*|*minecraftpe*|*clashofclans*|*clashroyale*|*pokemon*|*fifa*|*candy*|*eightball*|*candycrush*) genre="casual"; is_game=1 ;;
        esac

        if [ -f "$CUSTOM_GAMES_FILE" ] && grep -q "$pkg" "$CUSTOM_GAMES_FILE" 2>/dev/null; then
            is_game=1
            genre=$(grep "$pkg" "$CUSTOM_GAMES_FILE" | cut -d'|' -f3)
        fi

        [ "$first" = "0" ] && echo ","
        echo "  {\"pkg\":\"$pkg\",\"label\":\"$label\",\"isGame\":$is_game,\"genre\":\"$genre\"}"
        first=0
    done

    echo ""
    echo "]"
}

# ---- Add Custom Game ----
cmd_add() {
    local pkg="$1"
    local name="$2"
    local genre="${3:-battle_royale}"

    if [ -z "$pkg" ]; then
        echo "ERROR: Package name required"
        echo "Usage: $0 add <package> [name] [genre]"
        echo "Genres: moba, battle_royale, open_world, fps, racing, casual"
        return 1
    fi

    # Validate genre
    case "$genre" in
        moba|battle_royale|open_world|fps|racing|casual) ;;
        *) echo "ERROR: Invalid genre '$genre'"; return 1 ;;
    esac

    [ -z "$name" ] && name="$pkg"

    # Check if already exists
    if [ -f "$CUSTOM_GAMES_FILE" ] && grep -q "^$pkg|" "$CUSTOM_GAMES_FILE" 2>/dev/null; then
        echo "Package already added. Updating..."
        sed -i "/^$pkg|/d" "$CUSTOM_GAMES_FILE" 2>/dev/null
    fi

    # Append
    echo "$pkg|$name|$genre" >> "$CUSTOM_GAMES_FILE"
    echo "OK: Added '$name' ($pkg) as $genre"
}

# ---- Remove Custom Game ----
cmd_remove() {
    local pkg="$1"

    if [ -z "$pkg" ]; then
        echo "ERROR: Package name required"
        return 1
    fi

    if [ ! -f "$CUSTOM_GAMES_FILE" ]; then
        echo "No custom games file found"
        return 1
    fi

    if grep -q "^$pkg|" "$CUSTOM_GAMES_FILE" 2>/dev/null; then
        sed -i "/^$pkg|/d" "$CUSTOM_GAMES_FILE"
        echo "OK: Removed '$pkg'"
    else
        echo "Package '$pkg' not found in custom games"
    fi
}

# ---- List Custom Games ----
cmd_custom_list() {
    echo "=== Custom Games ==="
    if [ ! -f "$CUSTOM_GAMES_FILE" ] || [ ! -s "$CUSTOM_GAMES_FILE" ]; then
        echo "No custom games added yet"
        echo ""
        echo "Usage: $0 add <package> [name] [genre]"
        return
    fi

    local count=0
    while IFS='|' read -r pkg name genre; do
        [ -z "$pkg" ] && continue
        case "$pkg" in \#*) continue ;; esac
        echo "  $name ($pkg) — $genre"
        count=$((count + 1))
    done < "$CUSTOM_GAMES_FILE"

    echo ""
    echo "Total: $count custom game(s)"
}

# ---- Clear Custom Games ----
cmd_clear() {
    rm -f "$CUSTOM_GAMES_FILE"
    echo "OK: All custom games removed"
}

# ---- Main Dispatch ----
case "$1" in
    list)        cmd_list ;;
    info)        cmd_info "$2" ;;
    apply)       cmd_apply "$2" ;;
    custom)      cmd_apply "$2" ;;
    detect)      detect_running_game ;;
    auto)        cmd_auto ;;
    off)         cmd_off ;;
    status)      cmd_status ;;
    scan)        cmd_scan "$2" ;;
    scan-json)   cmd_scan_json "$2" ;;
    add)         cmd_add "$2" "$3" "$4" ;;
    remove)      cmd_remove "$2" ;;
    custom-list) cmd_custom_list ;;
    clear)       cmd_clear ;;
    *)
        echo "OpenGL Renderer Ultimate — Game Mode"
        echo ""
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  list              List all game presets"
        echo "  info <pkg>        Show preset info"
        echo "  apply <pkg>       Apply game preset"
        echo "  auto              Auto-detect running game"
        echo "  detect            Detect foreground game"
        echo "  off               Revert to defaults"
        echo "  status            Show current game mode"
        echo "  scan [filter]     Scan installed apps"
        echo "  scan-json [f]     Scan as JSON for WebUI"
        echo "  add <pkg> [n] [g] Add custom game"
        echo "  remove <pkg>      Remove custom game"
        echo "  custom-list       List custom games"
        echo "  clear             Remove all custom games"
        ;;
esac
