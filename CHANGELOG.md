# Changelog

All notable changes to OpenGL Renderer Ultimate will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v3.2.4] - 2026-08-22

### Changed
- **WebUI redesign** — iOS-style bottom navigation bar + sheet menu for secondary tabs
- Fully responsive design with safe area insets for notch devices
- Frosted glass header/nav with backdrop-filter blur
- Swipe-down to dismiss sheet menu
- iOS-style toggle switches and rounded card design

### Fixed
- **Universal root manager support** — `update-binary` now detects Magisk, Kitsune Magisk, KernelSU, APatch, SukiSU and routes installer accordingly
- Fixed `customize.sh` version string to v3.2.3

---

## [v3.2.3] - 2026-08-22

### Fixed
- **WebUI shell exec API** — `ksu.exec` callback now handles both string and object result formats across KernelSU versions. Previously all WebUI data showed as "-" and dashboard stayed on "Loading..." forever.
- **KernelSU auto-update notifications** — added `updateJson` URL to `module.prop` so KernelSU Manager can fetch `update.json` for update prompts.

---

## [v3.2.2] - 2026-08-22

### Added
- Module banner image (`system/banner.png`) for KernelSU Manager display
- 500x120 Neo-Brutalism styled banner with yellow/teal/pink accents
- Pure Python banner generator (`gen_banner.py`)

---

## [v3.2.0] - 2026-08-22

### Added
- **Game Mode Daemon** — auto-detect foreground game and apply preset automatically
  - Monitors foreground app every 3 seconds
  - Auto-applies genre preset when game detected
  - Auto-reverts when game is closed
  - Start/stop/status controls in WebUI
- **Quick Toggle** — toggle game mode on/off from terminal
  - `quick_toggle.sh` — toggle, on, off, status
- **Manual Update Checker** — `check_update.sh` with 3 modes
  - Default: check and display update info
  - Force: download ZIP and show install instructions
  - Auto: silent check for scripting
- Daemon auto-starts on boot via `service.sh`
- Auto-update check on boot (silent)
- WebUI daemon controls (start/stop/status)

### Changed
- `service.sh` now starts game mode daemon on boot
- `service.sh` now checks for updates on boot (silent)

---

## [v3.1.0] - 2026-08-22

### Added
- GitHub Actions CI — auto-build flashable ZIP on every push to main
- GitHub Actions CI — auto-create GitHub Release when tag is pushed
- `update.json` for KernelSU auto-update notifications
- `CHANGELOG.md` with comprehensive version history
- `CONTRIBUTING.md` with development setup guide
- `check_update.sh` — manual update checker script
- Auto-update support via `update.json` for KernelSU module notifications
- CI now attaches `update.json` to GitHub Releases

### Fixed
- CI workflow tags trigger for auto-release on tag push

### Changed
- Module version bumped to v3.1.0 (versionCode 310)

---

## [v3.0.0] - 2026-08-22

### Added

#### WebUI (12 Tabs)
- **Home Dashboard** — Device status at a glance (CPU, GPU, RAM, Battery, Thermal, Network)
- **CPU** — Governor, frequency limits, boost, scheduler tuning
- **GPU** — Vendor-specific (Adreno/Mali/Xclipse), overclock, force clk/bus/rail
- **RAM** — Swappiness, ZRAM, KSM, I/O scheduler, THP, zswap
- **Kernel** — Scheduler, sysctl, security, BPF JIT, ptrace
- **Network** — TCP BBR/Cubic, buffers, FastOpen, WiFi power save
- **Thermal** — Performance/Balanced/Cool modes, throttle temps
- **Overclock** — CPU+GPU+Bus+I/O max performance, one-tap
- **OpenGL** — HWUI renderer, RenderEngine, cache sizes, animation speed
- **Profiles** — Backup/restore, export/import, auto-apply on boot
- **Benchmark** — CPU/RAM/GPU/IO tests with before/after comparison
- **Game Mode** — 26+ game presets, custom game add, app scanner

#### Shell Scripts (13)
- `apply_cpu.sh` — CPU governor, frequency, scheduler, thermal
- `apply_gpu.sh` — GPU vendor-specific (Adreno KGSL, Mali devfreq, Xclipse)
- `apply_ram.sh` — RAM, ZRAM, KSM, I/O, THP, zswap, readahead
- `apply_kernel.sh` — Kernel sysctl, scheduler, security
- `apply_network.sh` — TCP congestion, buffers, FastOpen, WiFi
- `apply_thermal.sh` — Thermal zones, throttling control
- `apply_overclock.sh` — Max CPU+GPU+Bus+I/O performance
- `apply_profile.sh` — Profile save/load/delete/rename/duplicate/export/import
- `apply_gamemode.sh` — Game presets, genre optimization, app scanner
- `benchmark.sh` — CPU/RAM/GPU/IO benchmarks with comparison
- `auto_detect.sh` — Hardware detection + optimal profile recommendation
- `dashboard.sh` — System status JSON for WebUI dashboard
- `functions.sh` — Shared helpers (log, sp, detect, config)

#### Game Mode
- 6 genre presets (Battle Royale, MOBA, Open World, FPS, Racing, Casual)
- 26+ named game presets (PUBG, MLBB, Genshin, Free Fire, COD, etc.)
- Custom game add with package name + genre selection
- Scan all installed apps and select which to optimize
- Auto-detect running game and apply genre preset
- Game Mode OFF — revert all settings to defaults

#### Profiles
- Save current settings as named profile
- Load/apply any saved profile
- Delete/Rename/Duplicate profiles
- Export profiles to `/sdcard/OpenGLProfiles/` as `.tar.gz`
- Import profiles from `.tar.gz` files
- Auto-apply profile on boot
- Full system state snapshot per profile (CPU, GPU, RAM, Net, Thermal)

#### Benchmark
- CPU benchmark (integer, float, process creation)
- RAM benchmark (write/read bandwidth, allocation latency)
- I/O benchmark (sequential, random 4K)
- GPU benchmark (clock speed, sysfs read)
- Before/after comparison with percentage diff
- Color-coded result cards

#### Auto-Detect
- Hardware scan (device, SoC, CPU, GPU, RAM, thermal, kernel, storage)
- Smart profile recommendation (Flagship/High-End/Mid-Range/Low-End)
- One-click apply optimal settings
- Custom ROM detection (LineageOS, crDroid, PixelExperience, etc.)

#### Anti-Relog
- Persistent properties via `/data/local.prop`
- Config saved to `/data/local/opengl_renderer/config.conf`
- Properties survive reboots

#### UI/UX
- Neo-Brutalism + Retro theme (bold borders, hard shadows, bright colors)
- Dark cream background (#f5f0e8) with yellow/teal/pink accents
- Space Grotesk bold typography
- SVG icons (no emoji hardcodes)
- Responsive design (mobile-first)
- Toggle switches, range sliders, dropdowns
- Live status bar with success/error/warning states

#### Infrastructure
- Flashable ZIP for KernelSU/Magisk/APatch
- `META-INF/` installer with `update-binary` and `updater-script`
- `customize.sh` installer (permissions, dirs, config)
- `post-fs-data.sh` (early boot optimizations)
- `service.sh` (late boot optimizations)
- `uninstall.sh` (cleanup on removal)
- `module.prop` with module metadata

### Performance
- Skia OpenGL renderer forced for HWUI
- RenderEngine forced to Skia GL backend
- All debug/tracing disabled (Skia, ATrace, Perfetto)
- HWUI hint manager enabled with 25ms CPU budget
- Texture cache 96MB, Layer cache 48MB
- Frame pacing enabled
- Multi-threaded HWUI pipeline
- Animation scale 0.5x (iOS-like smoothness)
- SurfaceFlinger triple buffering
- VSync phase offset reduced to 1ms
- UBWC/AFBC enabled for bandwidth compression
- BBR congestion control with FQ queue discipline
- TCP FastOpen, MTU probing, large buffers
- WiFi power save disabled in game mode
- BFQ I/O scheduler with 256 requests
- KSM enabled for memory deduplication
- Zswap with LZ4 compression
- Transparent Huge Pages (madvise mode)

---

## [Unreleased]

### Planned
- Custom rule engine for per-app settings
- Battery temperature warning and auto-throttle
- More game presets (2025-2026 titles)
- Localization (Indonesian, Chinese, Korean)
- Dark/Light theme toggle
- Widget for quick settings tile
- Tasker/Automate integration

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| v3.2.4 | 2026-08-22 | iOS-style UI redesign + Universal root manager support |
| v3.2.3 | 2026-08-22 | Fix WebUI shell exec API + KernelSU auto-update support |
| v3.2.2 | 2026-08-22 | Module banner for KernelSU Manager |
| v3.2.1 | 2026-08-22 | Module banner for KernelSU Manager |
| v3.2.0 | 2026-08-22 | Game Mode Daemon, Quick Toggle, Manual Update Checker |
| v3.1.0 | 2026-08-22 | CI auto-build, auto-release, update.json, CONTRIBUTING.md |
| v3.0.0 | 2026-08-22 | Full rewrite: 12-tab WebUI, Game Mode, Profiles, Benchmark, Auto-Detect |
| v1.0.0 | - | Initial release: Basic OpenGL renderer properties |

---

## Links

- **Repository**: https://github.com/dikaofc/opengl-renderer-ultimate
- **Releases**: https://github.com/dikaofc/opengl-renderer-ultimate/releases
- **Issues**: https://github.com/dikaofc/opengl-renderer-ultimate/issues
- **Discussions**: https://github.com/dikaofc/opengl-renderer-ultimate/discussions
