# OpenGL Renderer Ultimate

> Ultimate GPU/CPU/RAM/Kernel tuner with WebUI for KernelSU/Magisk/APatch — max performance, iOS-like smoothness, no limits.

[![GitHub release](https://img.shields.io/github/v/release/dikaofc/opengl-renderer-ultimate?style=for-the-badge&color=blue)](https://github.com/dikaofc/opengl-renderer-ultimate/releases)
[![GitHub downloads](https://img.shields.io/github/downloads/dikaofc/opengl-renderer-ultimate/total?style=for-the-badge&color=green)](https://github.com/dikaofc/opengl-renderer-ultimate/releases)
[![License](https://img.shields.io/github/license/dikaofc/opengl-renderer-ultimate?style=for-the-badge&color=yellow)](LICENSE)
[![Android](https://img.shields.io/badge/Android-7.0%2B-brightgreen?style=for-the-badge)](https://developer.android.com)
[![KernelSU](https://img.shields.io/badge/KernelSU-Magisk-APatch-orange?style=for-the-badge)](https://kernelsu.org)

---

## Features

| Feature | Description |
|---------|-------------|
| **12-Tab WebUI** | Full control panel accessible from KernelSU Manager |
| **Home Dashboard** | Device status at a glance — CPU, GPU, RAM, Battery, Thermal |
| **CPU Control** | Governor, frequency limits, boost, scheduler tuning |
| **GPU Control** | Vendor-specific (Adreno/Mali/Xclipse), overclock, force clk/bus/rail |
| **RAM Management** | Swappiness, ZRAM, KSM, I/O scheduler, THP |
| **Kernel Tuning** | Scheduler, sysctl, security, BPF JIT |
| **Network Optimization** | TCP BBR/Cubic, buffers, FastOpen, WiFi power save |
| **Thermal Control** | Performance/Balanced/Cool modes, throttle temps |
| **Overclock** | CPU+GPU+Bus+I/O max performance, one-tap |
| **OpenGL Renderer** | HWUI, RenderEngine, cache sizes, animation speed |
| **Profiles** | Backup/restore, export/import, auto-apply on boot |
| **Benchmark** | CPU/RAM/GPU/IO tests with before/after comparison |
| **Game Mode** | 26+ game presets, custom game add, app scanner |
| **Auto-Detect** | Hardware scan + optimal profile recommendation |
| **Anti-Relog** | Persistent properties survive reboots |
| **Universal** | Works on ANY root + custom ROM device |

---

## Screenshots

### Home Dashboard
```
┌─────────────────────────────────────────────────────┐
│  Samsung Galaxy S24 Ultra                           │
│  Android 15  Snapdragon 8 Gen 3  Up 2d 5h 32m     │
├───────────┬───────────┬───────────┬─────────────────┤
│   CPU     │   GPU     │   RAM     │   Battery       │
│   32%     │    8%     │   58%     │   92%           │
│ 4/8 2.4G  │ Adreno    │ 4.6/8GB   │ Charging        │
│ ▓▓▓░░░░░░ │ ▓░░░░░░░░ │ ▓▓▓▓▓░░░░ │ ▓▓▓▓▓▓▓▓░░     │
├───────────┼───────────┼───────────┼─────────────────┤
│  Storage  │  Thermal  │  Network  │  Game Mode      │
│   45%     │  41.2C    │  Connected│  ACTIVE         │
│ 58/128GB  │ 12 zones  │ 192.168.1 │  PUBG Mobile    │
│ ▓▓▓▓░░░░░ │ ▓▓░░░░░░░ │ ▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓     │
└───────────┴───────────┴───────────┴─────────────────┘

[Apply All] [Benchmark] [Auto Detect] [Scan HW] [Save] [Reboot]
```

### Game Mode
```
┌─────────────────────────────────────────────────────┐
│  Quick Genre Presets                                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │ Battle   │ │   MOBA   │ │  Open    │            │
│  │ Royale   │ │          │ │  World   │            │
│  │ PUBG,FF  │ │ MLBB,WR  │ │ Genshin  │            │
│  └──────────┘ └──────────┘ └──────────┘            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │   FPS    │ │  Racing  │ │  Casual  │            │
│  │ COD,PUBG │ │ Asphalt9 │ │ Roblox   │            │
│  └──────────┘ └──────────┘ └──────────┘            │
│                                                     │
│  Scan Installed Apps                                │
│  Filter [tencent, miHoYo          ]                │
│  [Scan All Apps]  [Scan Games Only]                │
│                                                     │
│  ☑ PUBG Mobile                  [Battle Royale]    │
│    com.tencent.ig                                   │
│  ☑ Mobile Legends               [MOBA]             │
│    com.mobile.legends                               │
│  ☑ Genshin Impact               [Open World]       │
│    com.miHoYo.GenshinImpact                        │
│  ☐ Chrome                                         │
│    com.android.chrome                               │
└─────────────────────────────────────────────────────┘
```

### Benchmark Results
```
┌───────────┬───────────┬───────────┬─────────────────┐
│    CPU    │    RAM    │    I/O    │     GPU         │
│ Combined  │  Write    │ Seq Write │    Score        │
│  12,450   │  2,340    │  1,890    │    850          │
│  ops/ms   │  KB/ms    │  KB/ms    │    pts          │
├───────────┼───────────┼───────────┼─────────────────┤
│ Integer   │   Read    │ Seq Read  │   Backend       │
│  15,200   │  3,120    │  2,450    │   kgsl          │
│  ops/ms   │  KB/ms    │  KB/ms    │                 │
└───────────┴───────────┴───────────┴─────────────────┘

Before vs After Comparison:
  Metric              Before    After     Change
  cpu.combined        8500      12450     +46%
  ram.write_bandwidth 1800      2340      +30%
  io.seq_write        1400      1890      +35%
```

---

## Installation

### Prerequisites

- **Android 7.0+** (SDK 24+)
- **Root access** via one of:
  - [KernelSU](https://kernelsu.org) / [KernelSU Next](https://kernelsu.org)
  - [Magisk](https://github.com/topjohnwu/Magisk)
  - [APatch](https://github.com/bmax121/APatch)

### Method 1: Flash ZIP (Recommended)

1. Download [`OpenGL_Renderer_Ultimate_v3.0.0_Flashable.zip`](https://github.com/dikaofc/opengl-renderer-ultimate/releases/download/v3.0.0/OpenGL_Renderer_Ultimate_v3.0.0_Flashable.zip) from [Releases](https://github.com/dikaofc/opengl-renderer-ultimate/releases)
2. Open your root manager (KernelSU/Magisk/APatch)
3. Go to **Modules** → **Install from storage**
4. Select the downloaded ZIP
5. Wait for installation to complete
6. **Reboot** your device

### Method 2: From Source

```bash
# Clone the repository
git clone https://github.com/dikaofc/opengl-renderer-ultimate.git

# Enter the directory
cd opengl-renderer-ultimate

# Create flashable ZIP
zip -r9 OpenGL_Renderer_Ultimate.zip . -x ".git/*"

# Flash via KernelSU/Magisk
# Transfer the ZIP to your phone and flash
```

---

## Usage

### WebUI (Recommended)

After installation:

1. Open **KernelSU Manager** (or Magisk Manager)
2. Go to **Modules** → **OpenGL Renderer Ultimate**
3. Tap **Launch** to open the WebUI
4. Use the tabs to configure everything

### Terminal (Advanced)

```bash
# Run as root
su

# Apply OpenGL renderer settings
sh /data/adb/modules/opengl_renderer_ultimate/opengl.sh

# Apply all optimizations
sh /data/adb/modules/opengl_renderer_ultimate/service.sh

# Run benchmark
sh /data/adb/modules/opengl_renderer_ultimate/scripts/benchmark.sh all

# Game mode
sh /data/adb/modules/opengl_renderer_ultimate/scripts/apply_gamemode.sh apply com.tencent.ig

# Auto-detect hardware and apply optimal
sh /data/adb/modules/opengl_renderer_ultimate/scripts/auto_detect.sh apply
```

---

## WebUI Tabs

| Tab | What It Does |
|-----|-------------|
| **Home** | Device dashboard — CPU, GPU, RAM, Battery, Thermal, Network status |
| **CPU** | Governor, frequency, boost, scheduler tuning |
| **GPU** | GPU governor, overclock, Adreno/Mali-specific tweaks |
| **RAM** | Swappiness, ZRAM, KSM, I/O scheduler, readahead |
| **Kernel** | Scheduler, fsync, BPF JIT, security settings |
| **Network** | TCP congestion, buffers, FastOpen, WiFi |
| **Thermal** | Thermal modes, throttle temps, headroom |
| **OC** | One-tap CPU+GPU+Bus+I/O overclock |
| **OpenGL** | HWUI renderer, RenderEngine, cache, animations |
| **Profiles** | Save/load/delete, export/import, auto-apply |
| **Benchmark** | CPU/RAM/GPU/IO tests, before/after comparison |
| **Game Mode** | 26+ presets, custom game add, app scanner |

---

## Game Mode Presets

| Genre | Games | CPU | GPU | Network | Thermal |
|-------|-------|-----|-----|---------|---------|
| **Battle Royale** | PUBG, Free Fire, COD, Fortnite | Max | Max | Low Latency | Performance |
| **MOBA** | MLBB, Wild Rift, Honor of Kings | Performance | Performance | Low Latency | Performance |
| **Open World** | Genshin, Star Rail, ZZZ, Wuthering | Max | Max | Balanced | Aggressive |
| **FPS** | COD Mobile, PUBG | Max | Max | Ultra Low | Performance |
| **Racing** | Asphalt 9, NFS | Max | Max | Low Latency | Performance |
| **Casual** | Roblox, Minecraft, CoC, CR | Balanced | Balanced | Balanced | Balanced |

### Custom Games

Add any app to Game Mode:

```
gamemode.sh add com.example.mygame "My Game" battle_royale
gamemode.sh scan                          # Scan installed apps
gamemode.sh apply com.example.mygame      # Apply preset
```

---

## Auto-Detect Profiles

The module auto-detects your hardware and recommends optimal settings:

| Profile | Criteria | Behavior |
|---------|----------|----------|
| **Flagship** | 8 cores, 2.5GHz+, 6GB+ RAM | Max OC, performance everything |
| **High-End** | 8 cores, 2GHz+, 4GB+ RAM | Strong OC, aggressive scheduling |
| **Mid-Range** | 6+ cores, 1.5GHz+, 3GB+ RAM | Balanced, schedutil |
| **Low-End** | 4 cores or <1.5GHz or <3GB | Conservative, battery-friendly |

---

## Supported Devices

| Brand | Status |
|-------|--------|
| Samsung | Galaxy S21-S25, A-series, M-series |
| Xiaomi/POCO | All Snapdragon/Dimensity devices |
| OnePlus | All devices with root |
| Realme | RMX series, GT series |
| iQOO/ Vivo | All devices with root |
| Google Pixel | All Pixel devices |
| Nothing | Phone 1, Phone 2 |
| ASUS | ROG Phone, Zenfone |
| Any | Custom ROM (LineageOS, crDroid, etc.) |

---

## Module Structure

```
opengl-renderer-ultimate/
├── META-INF/                    # Magisk/KernelSU installer
├── module.prop                  # Module metadata
├── customize.sh                 # Installation script
├── post-fs-data.sh              # Early boot optimizations
├── service.sh                   # Late boot optimizations
├── uninstall.sh                 # Cleanup on removal
├── opengl.sh                    # Standalone OpenGL apply
├── scripts/
│   ├── functions.sh             # Shared helpers
│   ├── default.conf             # Default config
│   ├── apply_cpu.sh             # CPU tuning
│   ├── apply_gpu.sh             # GPU vendor-specific
│   ├── apply_ram.sh             # RAM, ZRAM, I/O
│   ├── apply_kernel.sh          # Kernel sysctl
│   ├── apply_network.sh         # TCP/network
│   ├── apply_thermal.sh         # Thermal control
│   ├── apply_overclock.sh       # Max performance
│   ├── apply_profile.sh         # Profile management
│   ├── apply_gamemode.sh        # Game presets + scanner
│   ├── benchmark.sh             # Performance tests
│   ├── auto_detect.sh           # Hardware detection
│   └── dashboard.sh             # System status JSON
└── webroot/
    ├── index.html               # WebUI (12 tabs, SVG icons)
    ├── style.css                # Neo-Brutalism theme
    └── app.js                   # Full control logic
```

---

## FAQ

**Q: Is this safe?**
A: Yes. All settings are non-critical. Unsupported properties are silently ignored by Android. Revert with "Game Mode OFF" or reboot.

**Q: Does it work on custom ROMs?**
A: Yes. Tested on LineageOS, crDroid, PixelExperience, Evolution, and more.

**Q: Will it drain my battery?**
A: Performance mode will use more battery. Use the "Balanced" or "Low-End" profile if battery is a concern.

**Q: How do I revert all changes?**
A: Reboot (most settings reset on reboot), or use the "Game Mode OFF" button, or uninstall the module.

**Q: Can I use this without KernelSU?**
A: Yes. It works with Magisk and APatch too.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Credits

- [KernelSU](https://kernelsu.org) for the module framework
- [Magisk](https://github.com/topjohnwu/Magisk) for the installer API
- Neo-Brutalism design inspired by [Saweria](https://saweria.co)

---

**Made with care for the Android root community.**
