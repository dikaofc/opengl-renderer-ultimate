# Changelog

## v3.1.0 (2026-08-22)

### Added
- GitHub Actions CI auto-build flashable ZIP on push
- GitHub Actions auto-create release when tag is pushed
- CONTRIBUTING.md development setup guide
- Auto-update support via `update.json` for KernelSU notifications
- `update.json` for KernelSU module update mechanism

### Fixed
- CI workflow tags trigger for auto-release

## v3.0.0 (2026-08-22)

### Features
- 12-tab WebUI control panel (Home, CPU, GPU, RAM, Kernel, Network, Thermal, OC, OpenGL, Profiles, Benchmark, Game Mode, Auto-Detect)
- Auto GPU vendor detection (Adreno, Mali, PowerVR, Xclipse)
- CPU/GPU/RAM/IO benchmark with before/after comparison
- Hardware auto-detect with optimal profile recommendation (Flagship/High-End/Mid-Range/Low-End)
- 26+ game presets with custom game add/scan
- Profile backup/restore with export/import
- Anti-relog persistent properties
- Neo-Brutalism + Retro UI theme with SVG icons
- Flashable ZIP for KernelSU/Magisk/APatch
- Home Dashboard with device status at a glance
- Game Mode with genre presets and app scanner
- Manual game add with custom package name
- Scan all installed apps and select which to optimize
